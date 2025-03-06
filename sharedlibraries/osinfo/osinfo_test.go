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

package osinfo

import (
	"context"
	"embed"
	"errors"
	"io"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

var (
	//go:embed test_data/os-release.txt test_data/os-release-bad.txt test_data/os-release-empty.txt
	testFS embed.FS
)

func TestReadData(t *testing.T) {
	defaultFileReader := FileReadCloser(func(path string) (io.ReadCloser, error) {
		file, err := testFS.Open(path)
		var f io.ReadCloser = file
		return f, err
	})
	tests := []struct {
		name     string
		reader   FileReadCloser
		os       string
		filePath string
		want     Data
		wantErr  error
	}{
		{
			name:     "success",
			reader:   defaultFileReader,
			os:       "linux",
			filePath: "test_data/os-release.txt",
			want: Data{
				OSName:    "linux",
				OSVendor:  "debian",
				OSVersion: "11",
			},
			wantErr: nil,
		},
		{
			name:     "windows",
			reader:   defaultFileReader,
			os:       "windows",
			filePath: "test_data/os-release.txt",
			want: Data{
				OSName:    "windows",
				OSVendor:  "",
				OSVersion: "",
			},
			wantErr: nil,
		},
		{
			name:     "noFileReader",
			reader:   nil,
			os:       "linux",
			filePath: "test_data/os-release.txt",
			want: Data{
				OSName:    "linux",
				OSVendor:  "",
				OSVersion: "",
			},
			wantErr: cmpopts.AnyError,
		},
		{
			name:     "noFilePath",
			reader:   defaultFileReader,
			os:       "linux",
			filePath: "",
			want: Data{
				OSName:    "linux",
				OSVendor:  "",
				OSVersion: "",
			},
			wantErr: cmpopts.AnyError,
		},
		{
			name: "fileReadError",
			reader: FileReadCloser(func(path string) (io.ReadCloser, error) {
				return nil, errors.New("File Read Error")
			}),
			os:       "linux",
			filePath: "test_data/os-release.txt",
			want: Data{
				OSName:    "linux",
				OSVendor:  "",
				OSVersion: "",
			},
			wantErr: cmpopts.AnyError,
		},
		{
			name:     "fileParseError",
			reader:   defaultFileReader,
			os:       "linux",
			filePath: "test_data/os-release-bad.txt",
			want: Data{
				OSName:    "linux",
				OSVendor:  "",
				OSVersion: "",
			},
			wantErr: cmpopts.AnyError,
		},
		{
			name:     "emptyFile",
			reader:   defaultFileReader,
			os:       "linux",
			filePath: "test_data/os-release-empty.txt",
			want: Data{
				OSName:    "linux",
				OSVendor:  "",
				OSVersion: "",
			},
			wantErr: nil,
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := ReadData(context.Background(), test.reader, test.os, test.filePath)
			if cmp.Diff(err, test.wantErr, cmpopts.EquateErrors()) != "" {
				t.Errorf("ReadData() unexpected error, got %v want %v", err, test.wantErr)
			}
			if diff := cmp.Diff(got, test.want); diff != "" {
				t.Errorf("ReadData() unexpected diff (-want +got):\n%s", diff)
			}
		})
	}
}
