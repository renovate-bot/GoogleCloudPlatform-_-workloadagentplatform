//go:build windows

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

package vmid

import (
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

func TestGetVMID(t *testing.T) {
	testCases := []struct {
		name        string
		queryErr    error
		queryResult []Win32_BIOS
		wantVMID    string
		wantErr     error
	}{
		{
			name:        "success",
			queryResult: []Win32_BIOS{Win32_BIOS{SerialNumber: "VMware-01 23 45 67 89 ab cd ef-01 23 45 67 89 ab cd ef"}},
			wantVMID:    "01234567-89ab-cdef-0123-456789abcdef",
			wantErr:     nil,
		},
		{
			name:     "query_error",
			queryErr: cmpopts.AnyError,
			wantVMID: "",
			wantErr:  cmpopts.AnyError,
		},
		{
			name:        "empty_query_result",
			queryResult: []Win32_BIOS{},
			wantVMID:    "",
			wantErr:     cmpopts.AnyError,
		},
		{
			name:        "empty_serial_number",
			queryResult: []Win32_BIOS{Win32_BIOS{}},
			wantVMID:    "",
			wantErr:     cmpopts.AnyError,
		},
		{
			name:        "unexpected_prefix",
			queryResult: []Win32_BIOS{Win32_BIOS{SerialNumber: "GoogleCloud-0123456789ABCDEF0123456789ABCDEF"}},
			wantVMID:    "",
			wantErr:     ErrIsNotGCVE,
		},
		{
			name:        "parsing_error",
			queryResult: []Win32_BIOS{Win32_BIOS{SerialNumber: "VMware-01 23 45 67 89 ab cd ef-01 23"}},
			wantVMID:    "",
			wantErr:     cmpopts.AnyError,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Setup
			queryBIOS = func() ([]Win32_BIOS, error) {
				return tc.queryResult, nil
			}

			// Execute
			gotVMID, err := VMID()

			// Validate
			if !cmp.Equal(err, tc.wantErr, cmpopts.EquateErrors()) {
				t.Errorf("VMID() got error: %v, want: %v", err, tc.wantErr)
			}
			if gotVMID != tc.wantVMID {
				t.Errorf("VMID() = %s, want: %s", gotVMID, tc.wantVMID)
			}
		})
	}
}
