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

package gce

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"google.golang.org/api/compute/v1"
	"google.golang.org/api/option"
)

// fakeGCEHandler is a helper to mock GCE API responses.
type fakeGCEHandler struct {
	instanceResponse    *compute.Instance
	instanceError       int
	machineTypeResponse *compute.MachineType
	machineTypeError    int
}

func (h *fakeGCEHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if strings.Contains(r.URL.Path, "/instances/") {
		if h.instanceError != 0 {
			http.Error(w, "instance error", h.instanceError)
			return
		}
		if h.instanceResponse != nil {
			json.NewEncoder(w).Encode(h.instanceResponse)
			return
		}
	}

	if strings.Contains(r.URL.Path, "/machineTypes/") {
		if h.machineTypeError != 0 {
			http.Error(w, "machineType error", h.machineTypeError)
			return
		}
		if h.machineTypeResponse != nil {
			json.NewEncoder(w).Encode(h.machineTypeResponse)
			return
		}
	}

	http.Error(w, "Unknown request", http.StatusNotFound)
}

func setupTestServer(ctx context.Context, t *testing.T, handler http.Handler) (*compute.Service, func()) {
	t.Helper()
	server := httptest.NewServer(handler)

	service, err := compute.NewService(ctx, option.WithoutAuthentication(), option.WithEndpoint(server.URL))
	if err != nil {
		t.Fatalf("Failed to create compute service: %v", err)
	}

	return service, server.Close
}

func TestGetInstanceCPUAndMemorySize(t *testing.T) {
	ctx := context.Background()
	project := "test-project"
	zone := "us-central1-a"
	instanceName := "test-instance"
	machineTypeName := "n1-standard-1"
	machineTypeURL := fmt.Sprintf("https://www.googleapis.com/compute/v1/projects/%s/zones/%s/machineTypes/%s", project, zone, machineTypeName)

	tests := []struct {
		name         string
		handler      *fakeGCEHandler
		wantCPU      int64
		wantMemoryMB int64
		wantErr      bool
	}{
		{
			name: "Success",
			handler: &fakeGCEHandler{
				instanceResponse: &compute.Instance{
					Name:        instanceName,
					MachineType: machineTypeURL,
				},
				machineTypeResponse: &compute.MachineType{
					Name:      machineTypeName,
					GuestCpus: 1,
					MemoryMb:  3750,
				},
			},
			wantCPU:      1,
			wantMemoryMB: 3750,
		},
		{
			name: "InstanceRetrievalFailure",
			handler: &fakeGCEHandler{
				instanceError: http.StatusNotFound,
			},
			wantErr: true,
		},
		{
			name: "MachineTypeURLEmpty",
			handler: &fakeGCEHandler{
				instanceResponse: &compute.Instance{
					Name:        instanceName,
					MachineType: "", // Empty MachineType URL
				},
			},
			wantErr: true,
		},
		{
			name: "MachineTypeGetFails",
			handler: &fakeGCEHandler{
				instanceResponse: &compute.Instance{
					Name:        instanceName,
					MachineType: machineTypeURL,
				},
				machineTypeError: http.StatusInternalServerError,
			},
			wantErr: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			service, teardown := setupTestServer(ctx, t, tc.handler)
			defer teardown()
			// Create a GCE instance with the fake service
			gceService := &GCE{service: service}

			gotCPU, gotMemoryMB, gotErr := gceService.GetInstanceCPUAndMemorySize(ctx, project, zone, instanceName)

			if (gotErr != nil) != tc.wantErr {
				t.Errorf("GetInstanceCPUAndMemorySize() returned error: %v, want error: %v", gotErr, tc.wantErr)
			}

			if gotCPU != tc.wantCPU {
				t.Errorf("GetInstanceCPUAndMemorySize() = %d CPU, want %d CPU", gotCPU, tc.wantCPU)
			}

			if gotMemoryMB != tc.wantMemoryMB {
				t.Errorf("GetInstanceCPUAndMemorySize() = %d MB Memory, want %d MB Memory", gotMemoryMB, tc.wantMemoryMB)
			}
		})
	}
}
