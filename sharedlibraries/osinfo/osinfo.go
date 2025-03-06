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

// Package osinfo can be used to read OS and vendor related information from a
// known source file. For Linux-based systems, the /etc/os-release file is
// used.
//
// This package does not support Windows based systems.
package osinfo

import (
	"context"
	"fmt"
	"io"
	"runtime"
	"strings"

	"github.com/zieckey/goini"
	"github.com/GoogleCloudPlatform/workloadagentplatform/sharedlibraries/log"
)

const (
	// OSName is given by runtime.GOOS.
	OSName = runtime.GOOS
	// OSReleaseFilePath lists the location of the os-release file in the Linux system.
	OSReleaseFilePath = "/etc/os-release"
)

type (
	// Data contains the OS related data.
	Data struct {
		OSName    string
		OSVendor  string
		OSVersion string
	}

	// FileReadCloser is a function which reads an input file and returns the
	// io.ReadCloser. It is created to facilitate testing.
	FileReadCloser func(string) (io.ReadCloser, error)
)

// ReadData returns the OS related information. In case of Windows, the vendor
// and version are empty.
func ReadData(ctx context.Context, rc FileReadCloser, os, filePath string) (Data, error) {
	res := Data{OSName: os}
	// TODO: b/401025374 - Add support for Windows.
	if res.OSName == "windows" {
		log.CtxLogger(ctx).Info("Reading OS data for Windows is not supported")
		return res, nil
	}
	var err error
	res.OSVendor, res.OSVersion, err = readReleaseInfo(ctx, rc, filePath)
	if err != nil {
		log.CtxLogger(ctx).Errorw("Failed to read OS release info", "error", err)
	}
	return res, err
}

// readReleaseInfo parses the OS release file and retrieves the values for the
// osVendorID and osVersion.
func readReleaseInfo(ctx context.Context, cfr FileReadCloser, filePath string) (osVendorID, osVersion string, err error) {
	if cfr == nil || filePath == "" {
		return "", "", fmt.Errorf("both ConfigFileReader and OSReleaseFilePath must be set")
	}

	file, err := cfr(filePath)
	if err != nil {
		return "", "", err
	}
	defer file.Close()

	ini := goini.New()
	if err := ini.ParseFrom(file, "\n", "="); err != nil {
		return "", "", fmt.Errorf("failed to parse %s: %v", filePath, err)
	}

	id, ok := ini.Get("ID")
	if !ok {
		log.CtxLogger(ctx).Warn(fmt.Sprintf("Could not read ID from %s", filePath))
		id = ""
	}
	osVendorID = strings.ReplaceAll(strings.TrimSpace(id), `"`, "")

	version, ok := ini.Get("VERSION")
	if !ok {
		log.CtxLogger(ctx).Warn(fmt.Sprintf("Could not read VERSION from %s", filePath))
		version = ""
	}
	if vf := strings.Fields(version); len(vf) > 0 {
		osVersion = strings.ReplaceAll(strings.TrimSpace(vf[0]), `"`, "")
	}

	return osVendorID, osVersion, nil
}
