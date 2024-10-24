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

package onetime

import (
	"context"
	"fmt"

	"github.com/spf13/cobra"
	winsvc "github.com/kardianos/service"
	cpb "github.com/GoogleCloudPlatform/workloadagentplatform/integration/common/protos"
)

var winlogger winsvc.Logger

// Winservice has args for winservice subcommands.
type Winservice struct {
	Integration *cpb.Integration
	Service     winsvc.Service
	Daemon      *cobra.Command
	// NOTE: Context is needed because kardianos/service for windows does not pass the context
	// to the service.Start(), service.Stop(), and service .Run() methods.
	ctx context.Context
}

// Start implements the subcommand interface for winservice.
func (w *Winservice) Start(s winsvc.Service) error {
	winlogger.Info(fmt.Sprintf("Winservice Start - starting the service %s", w.Integration.GetAgentName()))
	go w.run()
	return nil
}

// Stop implements the subcommand interface for winservice.
func (w *Winservice) Stop(s winsvc.Service) error {
	winlogger.Info(fmt.Sprintf("Winservice Run - stopping the service %s", w.Integration.GetAgentName()))
	return nil
}

func (w *Winservice) run() {
	winlogger.Info(fmt.Sprintf("Winservice Run - executing the daemon for service %s", w.Integration.GetAgentName()))
	w.Daemon.Execute()
	winlogger.Info(fmt.Sprintf("Winservice Run - daemon execution is complete for service %s", w.Integration.GetAgentName()))
}

// NewWinServiceCommand returns a new winservice command.
func NewWinServiceCommand(ctx context.Context, integration *cpb.Integration, daemon *cobra.Command) *cobra.Command {
	w := &Winservice{
		Integration: integration,
		Daemon:      daemon,
		ctx:         ctx,
	}
	wsCmd := &cobra.Command{
		Use:   "winservice",
		Short: "windows service operations",
		RunE:  w.Execute,
	}
	wsCmd.SetContext(ctx)
	return wsCmd
}

// Execute implements the subcommand interface for winservice.
func (w *Winservice) Execute(cmd *cobra.Command, args []string) error {
	fmt.Println(fmt.Sprintf("Winservice Execute - starting the service %s", w.Integration.GetAgentName()))
	config := &winsvc.Config{
		Name:        w.Integration.GetAgentName(),
		DisplayName: w.Integration.GetAgentLongName(),
		Description: w.Integration.GetAgentLongName(),
	}
	s, err := winsvc.New(w, config)
	if err != nil {
		return fmt.Errorf("Winservice Execute - error creating Windows service manager interface for service %s: %s",
			w.Integration.GetAgentName(), err)
	}
	w.Service = s

	winlogger, err = s.Logger(nil)
	if err != nil {
		return fmt.Errorf("Winservice Execute - error creating Windows Event Logger for service %s: %s",
			w.Integration.GetAgentName(), err)
	}
	fmt.Println(fmt.Sprintf("Winservice Execute -Starting the %s service", w.Integration.GetAgentName()))
	winlogger.Info(fmt.Sprintf("Winservice Execute - Starting the %s service", w.Integration.GetAgentName()))

	err = s.Run()
	if err != nil {
		winlogger.Error(err)
	}
	winlogger.Info(fmt.Sprintf("Winservice Execute - The %s service is shutting down", w.Integration.GetAgentName()))
	return nil
}
