/*
Copyright 2024 Google LLC

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

// Package usagemetrics provides logging utility for the operational status of platform agents.
package usagemetrics

import (
	"time"

	"github.com/jonboulle/clockwork"
	cpb "github.com/GoogleCloudPlatform/workloadagentplatform/integration/common/protos"
	"github.com/GoogleCloudPlatform/workloadagentplatform/integration/common/shared/log"
	"github.com/GoogleCloudPlatform/workloadagentplatform/integration/common/shared/usagemetrics"
)

// The following status values are supported.
const (
	StatusRunning       usagemetrics.Status = "RUNNING"
	StatusStarted       usagemetrics.Status = "STARTED"
	StatusStopped       usagemetrics.Status = "STOPPED"
	StatusConfigured    usagemetrics.Status = "CONFIGURED"
	StatusMisconfigured usagemetrics.Status = "MISCONFIGURED"
	StatusError         usagemetrics.Status = "ERROR"
	StatusInstalled     usagemetrics.Status = "INSTALLED"
	StatusUpdated       usagemetrics.Status = "UPDATED"
	StatusUninstalled   usagemetrics.Status = "UNINSTALLED"
	StatusAction        usagemetrics.Status = "ACTION"
)

// Global error codes, the first 50 are reserved for the platform, each integration should start from 51.
const (
	// GlobalUnknownError is the error id for unknown error.
	GlobalUnknownError = 0
	// GlobalConfigFileReadError is the error id for config file read failure.
	GlobalConfigFileReadError = 1
	// GlobalMalformedConfigFileError is the error id for malformed config file.
	GlobalMalformedConfigFileError = 2
)

// Global action codes, the first 50 are reserved for the platform, each integration should start from 51.
const (
	// GlobalUnknownAction is the action id for unknown action.
	GlobalUnknownAction = 0
)

// UsageLogger is the standard usage logger for the workload agent.
// We are not using the project exclusion list for the platform agents.
var UsageLogger = usagemetrics.NewLogger(nil, nil, clockwork.NewRealClock(), []string{})

// SetProperties sets the configured agent properties on the standard Logger.
func SetProperties(agentName, agentVersion string, logUsageMetrics bool, cp *cpb.CloudProperties) {
	if cp == nil {
		log.Logger.Error("CloudProperties is nil, not configuring usage metrics.")
		return
	}
	UsageLogger.SetAgentProps(
		&usagemetrics.AgentProperties{
			Name:            agentName,
			Version:         agentVersion,
			LogUsageMetrics: logUsageMetrics,
			LogUsagePrefix:  "gwap",
		})
	UsageLogger.SetCloudProps(&usagemetrics.CloudProperties{
		ProjectID:     cp.ProjectId,
		Zone:          cp.Zone,
		InstanceName:  cp.InstanceName,
		ProjectNumber: cp.GetNumericProjectId(),
		Image:         cp.Image,
	})
}

// ParseStatus parses the status string to a Status enum.
func ParseStatus(status string) usagemetrics.Status {
	return usagemetrics.Status(status)
}

// Running uses the standard Logger to log the RUNNING status. This status is reported at most once per day.
func Running() {
	UsageLogger.Running()
}

// Started uses the standard Logger to log the STARTED status.
func Started() {
	UsageLogger.Started()
}

// Stopped uses the standard Logger to log the STOPPED status.
func Stopped() {
	UsageLogger.Stopped()
}

// Configured uses the standard Logger to log the CONFIGURED status.
func Configured() {
	UsageLogger.Configured()
}

// Misconfigured uses the standard Logger to log the MISCONFIGURED status.
func Misconfigured() {
	UsageLogger.Misconfigured()
}

// Error uses the standard Logger to log the ERROR status. This status is reported at most once per day.
func Error(id int) {
	UsageLogger.Error(id)
}

// Installed uses the standard Logger to log the INSTALLED status.
func Installed() {
	UsageLogger.Installed()
}

// Updated uses the standard Logger to log the UPDATED status.
func Updated(version string) {
	UsageLogger.Updated(version)
}

// Uninstalled uses the standard Logger to log the UNINSTALLED status.
func Uninstalled() {
	UsageLogger.Uninstalled()
}

// Action uses the standard Logger to log the ACTION status.
func Action(id int) {
	UsageLogger.Action(id)
}

// LogRunningDaily log that the agent is running once a day.
func LogRunningDaily() {
	if UsageLogger.IsDailyLogRunningStarted() {
		log.Logger.Debugw("Daily log of RUNNING status already started")
		return
	}
	UsageLogger.DailyLogRunningStarted()
	log.Logger.Debugw("Starting daily log of RUNNING status")
	for {
		UsageLogger.Running()
		// sleep for 24 hours and a minute.
		time.Sleep(24*time.Hour + 1*time.Minute)
	}
}

// LogActionDaily uses the standard logger to log the ACTION once a day.
// Should be called exactly once for each ACTION code.
func LogActionDaily(id int) {
	log.Logger.Debugw("Starting daily log action", "ACTION", id)
	for {
		// sleep for 24 hours and a minute.
		time.Sleep(24*time.Hour + 1*time.Minute)
		UsageLogger.Action(id)
	}
}
