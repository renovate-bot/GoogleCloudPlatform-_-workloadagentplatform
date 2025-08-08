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

// Package vmid provides functions to get the ID of a GCVE VM.
package vmid

import (
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/pborman/uuid"
	"github.com/yusufpapurcu/wmi"
)

// ErrIsNotGCVE is returned when the VM is not a GCVE VM.
var ErrIsNotGCVE = errors.New("VM is not a GCVE VM")

const vmWareSerialNumberPrefix = "VMware"
const removalRegex = `[-\s]` // Used to remove whitespace and hyphens

var queryBIOS = func() ([]Win32_BIOS, error) {
	var bios []Win32_BIOS
	err := wmi.Query(wmi.CreateQuery(&bios, ""), &bios)
	return bios, err
}

// Win32_BIOS is a WMI class that represents the BIOS information.
// https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-bios
type Win32_BIOS struct {
	SerialNumber string
}

// VMID returns the VM ID of the current GCVE VM.
func VMID() (string, error) {
	serialNumber, err := serialNumber()
	if err != nil {
		return "", err
	}

	uuid, err := extractUUID(serialNumber)
	if err != nil {
		return "", err
	}

	return formatUUID(uuid)
}

// serialNumber returns the serial number of a GCVE VM.
func serialNumber() (string, error) {
	bios, err := queryBIOS()
	if err != nil {
		return "", err
	}
	if len(bios) == 0 || bios[0].SerialNumber == "" {
		return "", fmt.Errorf("serial number not found")
	}
	return bios[0].SerialNumber, nil
}

// extractUUID extracts the UUID from the serial number of a GCVE VM.
func extractUUID(serialNumber string) (string, error) {
	if !strings.HasPrefix(serialNumber, vmWareSerialNumberPrefix) {
		return serialNumber, fmt.Errorf("%w: serial number does not have prefix %s", ErrIsNotGCVE, vmWareSerialNumberPrefix)
	}
	serialNumber = strings.TrimPrefix(serialNumber, vmWareSerialNumberPrefix)
	return regexp.MustCompile(removalRegex).ReplaceAllString(serialNumber, ""), nil
}

// formatUUID formats the given id.
func formatUUID(id string) (string, error) {
	formattedID := uuid.Parse(id)
	if formattedID == nil {
		return "", fmt.Errorf("failed to parse uuid: %s", id)
	}

	return formattedID.String(), nil
}
