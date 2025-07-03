/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Package usagemetrics provides logging utility for the operational status of Google Cloud Agents.
package usagemetrics

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"google.golang.org/api/compute/v1"
	"google.golang.org/api/run/v2"
	"golang.org/x/oauth2/google"
	"github.com/GoogleCloudPlatform/workloadagentplatform/sharedlibraries/gce/metadataserver"
	"github.com/GoogleCloudPlatform/workloadagentplatform/sharedlibraries/log"
)

// Status enumerates the supported usage logging statuses.
type Status string

// The following status values are supported.
const (
	StatusRunning       Status = "RUNNING"
	StatusStarted       Status = "STARTED"
	StatusStopped       Status = "STOPPED"
	StatusConfigured    Status = "CONFIGURED"
	StatusMisconfigured Status = "MISCONFIGURED"
	StatusError         Status = "ERROR"
	StatusInstalled     Status = "INSTALLED"
	StatusUpdated       Status = "UPDATED"
	StatusUninstalled   Status = "UNINSTALLED"
	StatusAction        Status = "ACTION"
)

var (
	lock = sync.Mutex{}
)

// The TimeSource interface is a wrapper around time functionality needed for usage metrics logging.
// A fake TimeSource can be supplied by tests to ensure test stability.
type TimeSource interface {
	Now() time.Time
	Since(t time.Time) time.Duration
}

// AgentProperties contains the properties of the agent used by UsageMetrics library.
type AgentProperties struct {
	Name             string
	Version          string
	LogUsageMetrics  bool
	LogUsagePrefix   string
	LogUsageOptional string // optional string to be added to the usage log: "UsageLogPrefix/AgentName/AgentVersion[/OptionalString]/Status"
}

func (ap *AgentProperties) getLogUsageMetrics() bool {
	if ap == nil {
		return false
	}
	return ap.LogUsageMetrics
}

// CloudProperties contains the properties of the cloud instance used by UsageMetrics library.
type CloudProperties struct {
	ProjectID     string
	ProjectNumber string
	Image         string
	// Platform identifies the compute environment, e.g., GCE or CLOUD_RUN.
	Platform string
	// GCE-specific properties
	Zone         string
	InstanceName string
	InstanceID   string
	// Cloud Run-specific properties
	Region  string
	JobName string
}

// A Logger is used to report the status of the agent to an internal metadata server.
type Logger struct {
	agentProps             *AgentProperties
	cloudProps             *CloudProperties
	timeSource             TimeSource
	isTestProject          bool
	lastCalled             map[Status]time.Time
	dailyLogRunningStarted bool
	projectExclusions      map[string]bool
	clientForTest          *http.Client // Cloud run needs a different authentocation method not available in test environemnts.
}

// NewLogger creates a new Logger with an initialized hash map of Status to a last called timestamp.
func NewLogger(agentProps *AgentProperties, cloudProps *CloudProperties, timeSource TimeSource, projectExclusions []string) *Logger {
	l := &Logger{
		agentProps:        agentProps,
		timeSource:        timeSource,
		lastCalled:        make(map[Status]time.Time),
		projectExclusions: make(map[string]bool),
	}
	l.setProjectExclusions(projectExclusions)
	l.SetCloudProps(cloudProps)
	return l
}

// DailyLogRunningStarted logs the RUNNING status.
func (l *Logger) DailyLogRunningStarted() {
	l.dailyLogRunningStarted = true
}

// IsDailyLogRunningStarted returns true if DailyLogRunningStarted was previously called.
func (l *Logger) IsDailyLogRunningStarted() bool {
	return l.dailyLogRunningStarted
}

// Running logs the RUNNING status.
func (l *Logger) Running() {
	l.LogStatus(StatusRunning, "")
}

// Started logs the STARTED status.
func (l *Logger) Started() {
	l.LogStatus(StatusStarted, "")
}

// Stopped logs the STOPPED status.
func (l *Logger) Stopped() {
	l.LogStatus(StatusStopped, "")
}

// Configured logs the CONFIGURED status.
func (l *Logger) Configured() {
	l.LogStatus(StatusConfigured, "")
}

// Misconfigured logs the MISCONFIGURED status.
func (l *Logger) Misconfigured() {
	l.LogStatus(StatusMisconfigured, "")
}

// Error logs the ERROR status.
func (l *Logger) Error(id int) {
	l.LogStatus(StatusError, fmt.Sprintf("%d", id))
}

// Installed logs the INSTALLED status.
func (l *Logger) Installed() {
	l.LogStatus(StatusInstalled, "")
}

// Updated logs the UPDATED status.
func (l *Logger) Updated(version string) {
	l.LogStatus(StatusUpdated, version)
}

// Uninstalled logs the UNINSTALLED status.
func (l *Logger) Uninstalled() {
	l.LogStatus(StatusUninstalled, "")
}

// Action logs the ACTION status.
func (l *Logger) Action(id int) {
	l.LogStatus(StatusAction, fmt.Sprintf("%d", id))
}

func (l *Logger) log(s string) error {
	log.Logger.Debugw("logging status", "status", s)
	if l.cloudProps == nil {
		log.Logger.Warn("Unable to send agent status without cloud properties.")
		return errors.New("unable to send agent status without cloud properties")
	}
	userAgent := buildUserAgent(l.agentProps, s)
	var err error
	switch l.cloudProps.Platform {
	case metadataserver.PlatformCloudRun:
		if l.cloudProps.Region == "" {
			log.Logger.Warn("Unable to send Cloud Run agent status without region in cloud properties")
			return errors.New("region is not set for Cloud Run")
		}
		err = l.requestCloudRunAPIWithUserAgent(buildRunURL(l.cloudProps), userAgent)
	default:
		if l.cloudProps.Zone == "" {
			log.Logger.Warn("Unable to send GCE agent status without zone in cloud properties")
			return errors.New("zone is not set for GCE")
		}
		err = l.requestComputeAPIWithUserAgent(buildComputeURL(l.cloudProps), userAgent)
	}

	if err != nil {
		log.Logger.Warnw("failed to send agent status", "error", err, "platform", l.cloudProps.Platform)
		return err
	}
	return nil
}

// LogStatus logs the agent status if usage metrics logging is enabled.
func (l *Logger) LogStatus(s Status, v string) {
	if !l.agentProps.getLogUsageMetrics() {
		return
	}
	msg := string(s)
	if v != "" {
		msg = fmt.Sprintf("%s/%s", string(s), v)
	}
	l.log(msg)
	lock.Lock()
	defer lock.Unlock()
	l.lastCalled[s] = l.timeSource.Now()
}

// requestComputeAPIWithUserAgent submits a GET request to the compute API with a custom user agent.
func (l *Logger) requestComputeAPIWithUserAgent(url, ua string) error {
	if l.isTestProject {
		return nil
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	req.Header.Add("Metadata-Flavor", "Google")
	req.Header.Add("User-Agent", ua)
	// Sets the consumer project for the request if it exists.
	if l.cloudProps != nil && l.cloudProps.ProjectID != "" {
		req.Header.Add("X-Goog-User-Project", l.cloudProps.ProjectID)
	}
	var client *http.Client
	if l.clientForTest != nil {
		client = l.clientForTest
	} else {
		var err error
		client, err = google.DefaultClient(context.Background(), compute.ComputeScope)
		if err != nil {
			// Fallback for environments where we can't get default credentials.
			log.Logger.Debugw("could not get default credentials, falling back to default http client", "error", err)
			client = http.DefaultClient
		}
	}
	if _, err = client.Do(req); err != nil {
		return err
	}
	return nil
}

// requestCloudRunAPIWithUserAgent submits a GET request to the Cloud Run API with a custom user agent.
func (l *Logger) requestCloudRunAPIWithUserAgent(url, ua string) error {
	if l.isTestProject {
		return nil
	}
	log.Logger.Debugw("requestCloudRunAPIWithUserAgent", "url", url, "ua", ua)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		log.Logger.Warnw("failed to create request", "error", err)
		return err
	}
	req.Header.Add("User-Agent", ua)
	// Sets the consumer project for the request if it exists.
	if l.cloudProps != nil && l.cloudProps.ProjectID != "" {
		req.Header.Add("X-Goog-User-Project", l.cloudProps.ProjectID)
	}
	var client *http.Client
	if l.clientForTest != nil {
		client = l.clientForTest
	} else {
		// Use the appropriate scope for Cloud Run Admin API.
		var err error
		client, err = google.DefaultClient(context.Background(), run.CloudPlatformScope)
		if err != nil {
			log.Logger.Warnw("failed to create default client", "error", err)
			return err
		}
	}
	if _, err := client.Do(req); err != nil {
		log.Logger.Warnw("failed to send request", "error", err)
		return err
	}
	log.Logger.Debugw("successfully sent request", "url", url, "ua", ua)
	return nil
}

// SetCloudProps sets the cloud properties and ensures that dependent fields are kept in sync.
func (l *Logger) SetCloudProps(cp *CloudProperties) {
	l.cloudProps = cp
	if cp != nil {
		l.isTestProject = l.projectExclusions[cp.ProjectNumber]
	} else {
		l.isTestProject = false
	}
}

// SetAgentProps sets the agent properties
func (l *Logger) SetAgentProps(ap *AgentProperties) {
	l.agentProps = ap
}

// SetProjectExclusions sets the project exclusions dictionary
func (l *Logger) setProjectExclusions(pe []string) {
	for _, p := range pe {
		l.projectExclusions[p] = true
	}
}

// LastCalled returns the last time a status was called.
func (l *Logger) LastCalled(s Status) time.Time {
	lock.Lock()
	defer lock.Unlock()
	return l.lastCalled[s]
}

// buildComputeURL returns a compute API URL with the proper projectId, zone, and instance name specified.
func buildComputeURL(cp *CloudProperties) string {
	computeAPIURL := "https://compute.googleapis.com/compute/v1/projects/%s/zones/%s/instances/%s"
	if cp == nil {
		return fmt.Sprintf(computeAPIURL, "unknown", "unknown", "unknown")
	}
	return fmt.Sprintf(computeAPIURL, cp.ProjectID, cp.Zone, cp.InstanceName)
}

// buildRunURL returns a Cloud Run Admin API URL for the specified job.
func buildRunURL(cp *CloudProperties) string {
	runAPIURL := "https://run.googleapis.com/v1/projects/%s/locations/%s/jobs/%s"
	if cp == nil {
		return fmt.Sprintf(runAPIURL, "unknown", "unknown", "unknown")
	}
	return fmt.Sprintf(runAPIURL, cp.ProjectID, cp.Region, cp.JobName)
}

// buildUserAgent returns a User-Agent string that will be submitted to the compute API.
//
// User-Agent is of the form "UsageLogPrefix/AgentName/AgentVersion[/OptionalString]/Status".
func buildUserAgent(ap *AgentProperties, status string) string {
	ua := fmt.Sprintf("%s/%s/%s", ap.LogUsagePrefix, ap.Name, ap.Version)
	if ap.LogUsageOptional != "" {
		ua = fmt.Sprintf("%s/%s", ua, ap.LogUsageOptional)
	}
	ua = fmt.Sprintf("%s/%s", ua, status)
	ua = strings.ReplaceAll(strings.ReplaceAll(ua, " ", ""), "\n", "")
	return ua
}
