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

// Package statushelper provides helper functions for checking the status
// of various agent functionalities like IAM roles, package versions etc.
package statushelper

import (
	"context"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"text/tabwriter"

	arpb "cloud.google.com/go/artifactregistry/apiv1/artifactregistrypb"
	"cloud.google.com/go/artifactregistry/apiv1"
	"github.com/fatih/color"
	"github.com/googleapis/gax-go/v2"
	"golang.org/x/mod/semver"
	"google.golang.org/api/iterator"
	"github.com/GoogleCloudPlatform/workloadagentplatform/sharedlibraries/commandlineexecutor"
	"github.com/GoogleCloudPlatform/workloadagentplatform/sharedlibraries/log"
	spb "github.com/GoogleCloudPlatform/workloadagentplatform/sharedprotos/status"
)

// ArtifactRegistryClient is a wrapper for the Google Artifact Registry client.
type ArtifactRegistryClient struct {
	Client *artifactregistry.Client
}

// ARClientInterface is an interface for the Google Artifact Registry client.
type ARClientInterface interface {
	ListVersions(ctx context.Context, req *arpb.ListVersionsRequest, opts ...gax.CallOption) VersionIterator
}

// VersionIterator is an interface for the Google Artifact Registry client.
type VersionIterator interface {
	Next() (*arpb.Version, error)
}

// ListVersions lists the versions of a package in Artifact Registry.
func (arClient *ArtifactRegistryClient) ListVersions(ctx context.Context, req *arpb.ListVersionsRequest, opts ...gax.CallOption) VersionIterator {
	return arClient.Client.ListVersions(ctx, req, opts...)
}

// Define color codes as an enum
type colorCode int

const (
	info colorCode = iota
	failure
	success
	faint
	hyperlink
)

const (
	osLinux   = "linux"
	osWindows = "windows"
)

var (
	tabWriter         = tabwriter.NewWriter(os.Stdout, 0, 0, 1, ' ', 0)
	osKernelRegex     = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)\.?(\d+)?$`)
	distroKernelRegex = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)\.?(\d+)?[\.-]?(.*)$`)
)

// printColor prints a string with the specified color code.
func printColor(code colorCode, str string, a ...any) {
	var colorString string
	switch code {
	case faint:
		colorString = color.New(color.Faint).Sprintf(str, a...)
	case info:
		colorString = fmt.Sprintf(str, a...)
	case failure:
		colorString = color.RedString(str, a...)
	case success:
		colorString = color.GreenString(str, a...)
	case hyperlink:
		colorString = color.CyanString(str, a...)
	default:
		colorString = fmt.Sprintf(str, a...)
	}
	fmt.Fprint(tabWriter, colorString)
}

// LatestVersionArtifactRegistry returns latest version of the agent package
// from artifact registry.
func LatestVersionArtifactRegistry(ctx context.Context, arClient ARClientInterface, projectName string, repositoryLocation string, repositoryName string, packageName string) (string, error) {
	var versions []string
	it := arClient.ListVersions(ctx, &arpb.ListVersionsRequest{
		Parent: fmt.Sprintf("projects/%s/locations/%s/repositories/%s/packages/%s", projectName, repositoryLocation, repositoryName, packageName),
	})
	for {
		resp, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return "", err
		}
		// Strip the repo, location, and package path from the response.
		versions = append(versions, resp.GetName()[strings.LastIndex(resp.GetName(), ":")+1:])
	}
	if len(versions) == 0 {
		return "", fmt.Errorf("no versions found for package: %s", packageName)
	}

	// Sort using semver versioning, convert "3.10-12345" to "v3.10.12345".
	sort.Slice(versions, func(i, j int) bool {
		v1 := "v" + strings.ReplaceAll(versions[i], "-", ".")
		v2 := "v" + strings.ReplaceAll(versions[j], "-", ".")
		return semver.Compare(v1, v2) < 0
	})
	return versions[len(versions)-1], nil
}

// KernelVersion returns the kernel version data for the system.
func KernelVersion(ctx context.Context, osType string, exec commandlineexecutor.Execute) (*spb.KernelVersion, error) {
	switch osType {
	case osLinux:
		return kernelVersionLinux(ctx, exec)
	case osWindows:
		// Windows kernel version is not supported at this time.
		return nil, fmt.Errorf("unsupported OS: %s", osType)
	default:
		return nil, fmt.Errorf("unsupported OS: %s", osType)
	}
}

// kernelVersionLinux returns the kernel version data for a linux system.
func kernelVersionLinux(ctx context.Context, exec commandlineexecutor.Execute) (*spb.KernelVersion, error) {
	result := exec(ctx, commandlineexecutor.Params{
		Executable: "uname",
		Args:       []string{"-r"},
	})
	if result.Error != nil {
		return nil, fmt.Errorf("failed to fetch kernel version data: %s", result.Error)
	}

	version := &spb.KernelVersion{RawString: result.StdOut}
	parts := strings.SplitN(result.StdOut, "-", 2)
	if len(parts) != 2 {
		log.CtxLogger(ctx).Debugw("Failed to parse kernel version data from stdout", "stdout", result.StdOut)
		return version, nil
	}

	safeAtoi := func(s string) int32 {
		if s == "" {
			return 0
		}
		// Suppressing the error here as the regex ensures that the string is numeric.
		number, _ := strconv.Atoi(s)
		return int32(number)
	}
	osKernelMatch := osKernelRegex.FindStringSubmatch(parts[0])
	if osKernelMatch == nil {
		log.CtxLogger(ctx).Debugw("failed to parse linux kernel version from stdout", "stdout", result.StdOut)
	} else {
		version.OsKernel = &spb.KernelVersion_Version{
			Major: safeAtoi(osKernelMatch[1]),
			Minor: safeAtoi(osKernelMatch[2]),
			Build: safeAtoi(osKernelMatch[3]),
			Patch: safeAtoi(osKernelMatch[4]),
		}
	}
	distroKernelMatch := distroKernelRegex.FindStringSubmatch(parts[1])
	if distroKernelMatch == nil {
		log.CtxLogger(ctx).Debugw("failed to parse distro kernel version from stdout", "stdout", result.StdOut)
	} else {
		version.DistroKernel = &spb.KernelVersion_Version{
			Major:     safeAtoi(distroKernelMatch[1]),
			Minor:     safeAtoi(distroKernelMatch[2]),
			Build:     safeAtoi(distroKernelMatch[3]),
			Patch:     safeAtoi(distroKernelMatch[4]),
			Remainder: distroKernelMatch[5],
		}
	}

	return version, nil
}

// CheckAgentEnabledAndRunning returns the status of the agent service.
//
// Returns a tuple as (isEnabled, isRunning, error).
func CheckAgentEnabledAndRunning(ctx context.Context, agentName string, osType string, exec commandlineexecutor.Execute) (isEnabled bool, isRunning bool, err error) {
	switch osType {
	case osLinux:
		return agentEnabledAndRunningLinux(ctx, agentName, exec)
	case osWindows:
		return agentEnabledAndRunningWindows(ctx, agentName, exec)
	default:
		return false, false, fmt.Errorf("unsupported OS: %s", osType)
	}
}

// agentEnabledAndRunningLinux returns the status of a service on linux using systemctl.
//
// Returns tuple of (isEnabled, isRunning, error)
func agentEnabledAndRunningLinux(ctx context.Context, serviceName string, exec commandlineexecutor.Execute) (isEnabled bool, isRunning bool, err error) {
	// 1. Check if the service is enabled to start at boot.
	result := exec(ctx, commandlineexecutor.Params{
		Executable:  "sudo",
		ArgsToSplit: fmt.Sprintf("systemctl is-enabled %s", serviceName),
	})
	if result.StdErr != "" {
		return false, false, fmt.Errorf("could not get the agent service enabled status: %#v", result)
	}

	isEnabled = false
	// systemctl is-enabled returns 0 for a number of service states, confirm
	// that the service is actually enabled.
	if result.ExitCode == 0 && strings.Contains(result.StdOut, "enabled") {
		isEnabled = true
	}

	// 2. Check if the service is running. Note that a service can be disabled
	// but still running.
	result = exec(ctx, commandlineexecutor.Params{
		Executable:  "sudo",
		ArgsToSplit: fmt.Sprintf("systemctl is-active %s", serviceName),
	})
	if result.StdErr != "" {
		return false, false, fmt.Errorf("could not get the agent service active status: %#v", result)
	}

	isRunning = false
	// is-running returns 0 only if the service is active.
	if result.ExitCode == 0 {
		isRunning = true
	}
	return isEnabled, isRunning, nil
}

// agentEnabledAndRunningWindows returns the status of the agent service on windows.
//
// Returns tuple of (isEnabled, isRunning, error)
func agentEnabledAndRunningWindows(ctx context.Context, serviceName string, exec commandlineexecutor.Execute) (isEnabled bool, isRunning bool, err error) {
	// Check if the service is running. Enabled is considered to be the same as running on windows.
	result := exec(ctx, commandlineexecutor.Params{
		Executable:  "Powershell",
		ArgsToSplit: fmt.Sprintf("(Get-Service -Name '%s' -ErrorAction Ignore).Status", serviceName),
	})
	stdOut := strings.TrimSpace(result.StdOut)
	if stdOut == "Running" {
		return true, true, nil
	}
	if stdOut == "Stopped" {
		return false, false, nil
	}
	return false, false, fmt.Errorf("could not get the agent service status: %#v", result)
}

// CheckIAMRoles checks if the required IAM roles are present.
func CheckIAMRoles(ctx context.Context, projectID string, requiredRoles []string) error {
	// Implement logic to check if the required IAM roles are present.
	return nil
}

// PrintStatus prints the status of the agent and the configured services to
// the console with appropriate formatting and coloring.
func PrintStatus(ctx context.Context, status *spb.AgentStatus, compact bool) {
	// Center the agent name between the header dashes and limit the width to 80 characters.
	printColor(info, "--------------------------------------------------------------------------------\n")
	printColor(info, "|%s|\n", fmt.Sprintf("%*s", -78, fmt.Sprintf("%*s", (78+len(status.GetAgentName()+" Status"))/2, status.GetAgentName()+" Status")))
	printColor(info, "--------------------------------------------------------------------------------\n")
	printColor(info, "Agent Status:\n")
	versionColor := success
	if status.GetInstalledVersion() != status.GetAvailableVersion() {
		versionColor = failure
	}
	printColor(info, "    Installed Version: ")
	printColor(versionColor, "%s\n", status.GetInstalledVersion())
	printColor(info, "    Available Version: ")
	printColor(versionColor, "%s\n", status.GetAvailableVersion())

	printState(ctx, "    Systemd Service Enabled", status.GetSystemdServiceEnabled())
	printState(ctx, "    Systemd Service Running", status.GetSystemdServiceRunning())
	printState(ctx, "    Cloud API Full Scopes", status.GetCloudApiAccessFullScopesGranted())
	printColor(info, "    Configuration File: %s\n", status.GetConfigurationFilePath())
	printState(ctx, "    Configuration Valid", status.GetConfigurationValid())
	if status.GetConfigurationValid() != spb.State_SUCCESS_STATE {
		printColor(failure, "        %s\n", status.GetConfigurationErrorMessage())
	}

	for _, service := range status.GetServices() {
		printServiceStatus(ctx, service, compact)
	}
	printReferences(ctx, status.GetReferences())
	printColor(info, "\n\n")
	tabWriter.Flush()
}

// printState prints a valid/invalid/error state with formatting and coloring.
func printState(ctx context.Context, name string, state spb.State) {
	printColor(info, "%s:\t", name)
	switch state {
	case spb.State_SUCCESS_STATE:
		printColor(success, "True\n")
	case spb.State_FAILURE_STATE:
		printColor(failure, "False\n")
	default:
		printColor(failure, "Error: could not determine status\n")
	}
}

// printServiceStatus prints the status of the service to the console with
// appropriate formatting and coloring.
func printServiceStatus(ctx context.Context, status *spb.ServiceStatus, compact bool) {
	printColor(info, "--------------------------------------------------------------------------------\n")
	switch status.GetState() {
	case spb.State_UNSPECIFIED_STATE:
		printColor(faint, "%s: %s\n", status.GetName(), status.GetUnspecifiedStateMessage())
		return
	case spb.State_FAILURE_STATE:
		printColor(faint, "%s: Disabled\n", status.GetName())
		return
	case spb.State_ERROR_STATE:
		if status.GetErrorMessage() == "" {
			status.ErrorMessage = "could not determine status"
		}
		printColor(failure, "%s: Error: %s\n", status.GetName(), status.GetErrorMessage())
		return
	default:
		printColor(info, "%s: ", status.GetName())
		printColor(success, "Enabled\n")
	}

	printColor(info, "    Status: ")
	if status.GetFullyFunctional() == spb.State_SUCCESS_STATE {
		printColor(success, "Fully Functional\n")
	} else {
		if status.GetErrorMessage() == "" {
			status.ErrorMessage = "could not determine status"
		}
		printColor(failure, "Error: %s\n", status.GetErrorMessage())
	}

	if len(status.GetIamPermissions()) > 0 {
		printColor(info, "    IAM Permissions: ")
		var deniedPermissions []*spb.IAMPermission
		for _, permission := range status.GetIamPermissions() {
			if permission.GetGranted() != spb.State_SUCCESS_STATE {
				deniedPermissions = append(deniedPermissions, permission)
			}
		}
		if len(deniedPermissions) == 0 {
			printColor(success, "All granted\n")
		} else {
			printColor(failure, "%d not granted (output limited to 5)\n", len(deniedPermissions))
		}
		if !compact {
			sort.Slice(deniedPermissions, func(i, j int) bool {
				return deniedPermissions[i].GetGranted() < deniedPermissions[j].GetGranted()
			})
			for i, permission := range deniedPermissions {
				if i >= 5 {
					break
				}
				printState(ctx, fmt.Sprintf("        %s", permission.GetName()), permission.GetGranted())
			}
		}
	}
	if compact {
		return
	}

	if len(status.GetConfigValues()) > 0 {
		printColor(info, "    Configuration:\n")
		sort.Slice(status.GetConfigValues(), func(i, j int) bool {
			return status.GetConfigValues()[i].GetName() < status.GetConfigValues()[j].GetName()
		})
	}
	for _, configValue := range status.GetConfigValues() {
		defaultString := "default"
		if !configValue.GetIsDefault() {
			defaultString = "configuration file"
		}
		if configValue.GetValue() == "" {
			printColor(info, "        %s:\tnil\t(%s)\n", configValue.GetName(), defaultString)
		} else {
			printColor(info, "        %s:\t%s\t(%s)\n", configValue.GetName(), configValue.GetValue(), defaultString)
		}
	}
}

func printReferences(ctx context.Context, references []*spb.Reference) {
	if len(references) == 0 {
		return
	}
	printColor(info, "--------------------------------------------------------------------------------\n")
	printColor(info, "References:\n")
	for _, reference := range references {
		printColor(info, "%s: ", reference.GetName())
		printColor(hyperlink, "%s\n", reference.GetUrl())
	}
}
