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

// Package onetime contains the one time executable commands that can be used by any agent.
package onetime

import (
	"fmt"

	"github.com/spf13/cobra"
	cpb "github.com/GoogleCloudPlatform/workloadagentplatform/integration/common/protos"
)

// Version has args for version subcommands.
type Version struct {
	Integration *cpb.Integration
}

// Execute implements the cobra command interface for version.
func (v *Version) Execute(cmd *cobra.Command, args []string) error {
	fmt.Println(fmt.Sprintf("%s version %s\n", v.Integration.GetAgentLongName(), v.Integration.GetAgentVersion()))
	return nil
}

// NewVersionCommand returns a new version command.
func NewVersionCommand(integration *cpb.Integration) *cobra.Command {
	v := &Version{Integration: integration}
	return &cobra.Command{
		Use:   "version",
		Short: "print agent version information",
		RunE:  v.Execute,
	}
}
