/*
Copyright 2025 Google LLC

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

// Package main serves as the Main entry point for the guest telemetry extension.
package main

import (
	"flag"
	"math/rand/v2"
	"os"
	"time"

	"go.uber.org/zap"
)

// required by extensions
var protocol string     // protocol to use uds/tcp
var address string      // address to start server listening on
var errorlogfile string // extension error log file

// optional configuration flags - will never be used by the extension in normal operation
// these are meant to aid in testing and debugging of the extension
// DEBUG ONLY
var channel string           // ACS channel Id, default none
var endpoint string          // ACS endpoint override, default none
var retrievalInterval string // discovery definition retrieval interval, default 3d
var discoveryInterval string // discovery detection interval, default 1d
var jitter bool              // if true add random jitter before main execution, default true
var logLevel string          // debug, info, warn, error, default info
var logFile string           // file to write logs to, default none
var dataFile string          // file to write discovered data to, default none
var definitionFile string    // file based discovery definitions, default none
var disableACS bool          // do not use ACS, local run only, default false

func main() {
	// Setup and parse flags.
	flag.StringVar(&protocol, "protocol", "", "protocol to use uds/tcp")
	flag.StringVar(&address, "address", "", "address to start server listening on")
	flag.StringVar(&errorlogfile, "errorlogfile", "", "extension error log file")

	flag.StringVar(&channel, "channel", "", "ACS channel Id")
	flag.StringVar(&endpoint, "endpoint", "", "ACS endpoint override")
	flag.StringVar(&retrievalInterval, "retrieval_interval", "", "discovery definition retrieval interval")
	flag.StringVar(&discoveryInterval, "discovery_interval", "", "discovery detection interval")
	flag.BoolVar(&jitter, "jitter", true, "if true add random jitter before main execution")
	flag.StringVar(&logLevel, "log_level", "info", "debug, info, warn, error")
	flag.StringVar(&logFile, "log_file", "", "file to write logs to")
	flag.StringVar(&dataFile, "data_file", "", "file to write discovered data to")
	flag.StringVar(&definitionFile, "definition_file", "", "file based discovery definitions")
	flag.BoolVar(&disableACS, "disable_acs", false, "do not use ACS, local run only")
	flag.Parse()

	// TODO: b/454623051 - Expand on this setup and ensure this writes to the correct log file.
	// Setup logging.
	logger, _ := zap.NewProduction()
	defer logger.Sync()
	sugarLogger := logger.Sugar()
	sugarLogger.Info("Guest Telemetry Extension started")

	// Sleep for some jitter time between 1 and 10 minutes.
	if jitter {
		max := 600
		min := 60
		duration := time.Duration(rand.IntN(max-min)+min) * time.Second
		time.Sleep(duration)
	}

	// 1. Start listening for discovery definitions on the ACS channel.
	// 2. Once received, start the discovery engine process.
	// 3. Once each discovery engine execution cycle is complete send the results on the ACS channel.
	// 4. Repeat the discovery engine execution process on a 1 day interval.
	// If during the sleep time we receive a new discovery definition, go to step 2.

	os.Exit(0)
}
