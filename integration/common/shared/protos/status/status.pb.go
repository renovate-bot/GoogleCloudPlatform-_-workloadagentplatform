//
//Copyright 2024 Google LLC
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//https://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.

// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.33.0
// 	protoc        v4.23.4
// source: integration/common/shared/protos/status/status.proto

package status

import (
	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
	reflect "reflect"
	sync "sync"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

type State int32

const (
	State_UNSPECIFIED_STATE State = 0
	State_SUCCESS_STATE     State = 1
	State_FAILURE_STATE     State = 2
	State_ERROR_STATE       State = 3
)

// Enum value maps for State.
var (
	State_name = map[int32]string{
		0: "UNSPECIFIED_STATE",
		1: "SUCCESS_STATE",
		2: "FAILURE_STATE",
		3: "ERROR_STATE",
	}
	State_value = map[string]int32{
		"UNSPECIFIED_STATE": 0,
		"SUCCESS_STATE":     1,
		"FAILURE_STATE":     2,
		"ERROR_STATE":       3,
	}
)

func (x State) Enum() *State {
	p := new(State)
	*p = x
	return p
}

func (x State) String() string {
	return protoimpl.X.EnumStringOf(x.Descriptor(), protoreflect.EnumNumber(x))
}

func (State) Descriptor() protoreflect.EnumDescriptor {
	return file_integration_common_shared_protos_status_status_proto_enumTypes[0].Descriptor()
}

func (State) Type() protoreflect.EnumType {
	return &file_integration_common_shared_protos_status_status_proto_enumTypes[0]
}

func (x State) Number() protoreflect.EnumNumber {
	return protoreflect.EnumNumber(x)
}

// Deprecated: Use State.Descriptor instead.
func (State) EnumDescriptor() ([]byte, []int) {
	return file_integration_common_shared_protos_status_status_proto_rawDescGZIP(), []int{0}
}

type AgentStatus struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	InstalledVersion          string           `protobuf:"bytes,1,opt,name=installed_version,json=installedVersion,proto3" json:"installed_version,omitempty"`
	AvailableVersion          string           `protobuf:"bytes,2,opt,name=available_version,json=availableVersion,proto3" json:"available_version,omitempty"`
	SystemdServiceEnabled     State            `protobuf:"varint,3,opt,name=systemd_service_enabled,json=systemdServiceEnabled,proto3,enum=cloud.partners.gwap.status.State" json:"systemd_service_enabled,omitempty"`
	SystemdServiceRunning     State            `protobuf:"varint,4,opt,name=systemd_service_running,json=systemdServiceRunning,proto3,enum=cloud.partners.gwap.status.State" json:"systemd_service_running,omitempty"`
	ConfigurationFilePath     string           `protobuf:"bytes,5,opt,name=configuration_file_path,json=configurationFilePath,proto3" json:"configuration_file_path,omitempty"`
	ConfigurationValid        State            `protobuf:"varint,6,opt,name=configuration_valid,json=configurationValid,proto3,enum=cloud.partners.gwap.status.State" json:"configuration_valid,omitempty"`
	ConfigurationErrorMessage string           `protobuf:"bytes,7,opt,name=configuration_error_message,json=configurationErrorMessage,proto3" json:"configuration_error_message,omitempty"`
	Services                  []*ServiceStatus `protobuf:"bytes,8,rep,name=services,proto3" json:"services,omitempty"`
	References                []*Reference     `protobuf:"bytes,9,rep,name=references,proto3" json:"references,omitempty"`
	AgentName                 string           `protobuf:"bytes,10,opt,name=agent_name,json=agentName,proto3" json:"agent_name,omitempty"`
}

func (x *AgentStatus) Reset() {
	*x = AgentStatus{}
	if protoimpl.UnsafeEnabled {
		mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[0]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *AgentStatus) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*AgentStatus) ProtoMessage() {}

func (x *AgentStatus) ProtoReflect() protoreflect.Message {
	mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[0]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use AgentStatus.ProtoReflect.Descriptor instead.
func (*AgentStatus) Descriptor() ([]byte, []int) {
	return file_integration_common_shared_protos_status_status_proto_rawDescGZIP(), []int{0}
}

func (x *AgentStatus) GetInstalledVersion() string {
	if x != nil {
		return x.InstalledVersion
	}
	return ""
}

func (x *AgentStatus) GetAvailableVersion() string {
	if x != nil {
		return x.AvailableVersion
	}
	return ""
}

func (x *AgentStatus) GetSystemdServiceEnabled() State {
	if x != nil {
		return x.SystemdServiceEnabled
	}
	return State_UNSPECIFIED_STATE
}

func (x *AgentStatus) GetSystemdServiceRunning() State {
	if x != nil {
		return x.SystemdServiceRunning
	}
	return State_UNSPECIFIED_STATE
}

func (x *AgentStatus) GetConfigurationFilePath() string {
	if x != nil {
		return x.ConfigurationFilePath
	}
	return ""
}

func (x *AgentStatus) GetConfigurationValid() State {
	if x != nil {
		return x.ConfigurationValid
	}
	return State_UNSPECIFIED_STATE
}

func (x *AgentStatus) GetConfigurationErrorMessage() string {
	if x != nil {
		return x.ConfigurationErrorMessage
	}
	return ""
}

func (x *AgentStatus) GetServices() []*ServiceStatus {
	if x != nil {
		return x.Services
	}
	return nil
}

func (x *AgentStatus) GetReferences() []*Reference {
	if x != nil {
		return x.References
	}
	return nil
}

func (x *AgentStatus) GetAgentName() string {
	if x != nil {
		return x.AgentName
	}
	return ""
}

type ServiceStatus struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Name            string           `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Enabled         bool             `protobuf:"varint,2,opt,name=enabled,proto3" json:"enabled,omitempty"`
	FullyFunctional State            `protobuf:"varint,3,opt,name=fully_functional,json=fullyFunctional,proto3,enum=cloud.partners.gwap.status.State" json:"fully_functional,omitempty"`
	ErrorMessage    string           `protobuf:"bytes,4,opt,name=error_message,json=errorMessage,proto3" json:"error_message,omitempty"`
	IamPermissions  []*IAMPermission `protobuf:"bytes,5,rep,name=iam_permissions,json=iamPermissions,proto3" json:"iam_permissions,omitempty"`
	ConfigValues    []*ConfigValue   `protobuf:"bytes,6,rep,name=config_values,json=configValues,proto3" json:"config_values,omitempty"`
}

func (x *ServiceStatus) Reset() {
	*x = ServiceStatus{}
	if protoimpl.UnsafeEnabled {
		mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[1]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *ServiceStatus) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*ServiceStatus) ProtoMessage() {}

func (x *ServiceStatus) ProtoReflect() protoreflect.Message {
	mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[1]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use ServiceStatus.ProtoReflect.Descriptor instead.
func (*ServiceStatus) Descriptor() ([]byte, []int) {
	return file_integration_common_shared_protos_status_status_proto_rawDescGZIP(), []int{1}
}

func (x *ServiceStatus) GetName() string {
	if x != nil {
		return x.Name
	}
	return ""
}

func (x *ServiceStatus) GetEnabled() bool {
	if x != nil {
		return x.Enabled
	}
	return false
}

func (x *ServiceStatus) GetFullyFunctional() State {
	if x != nil {
		return x.FullyFunctional
	}
	return State_UNSPECIFIED_STATE
}

func (x *ServiceStatus) GetErrorMessage() string {
	if x != nil {
		return x.ErrorMessage
	}
	return ""
}

func (x *ServiceStatus) GetIamPermissions() []*IAMPermission {
	if x != nil {
		return x.IamPermissions
	}
	return nil
}

func (x *ServiceStatus) GetConfigValues() []*ConfigValue {
	if x != nil {
		return x.ConfigValues
	}
	return nil
}

type IAMPermission struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Name    string `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Granted State  `protobuf:"varint,3,opt,name=granted,proto3,enum=cloud.partners.gwap.status.State" json:"granted,omitempty"`
}

func (x *IAMPermission) Reset() {
	*x = IAMPermission{}
	if protoimpl.UnsafeEnabled {
		mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[2]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *IAMPermission) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*IAMPermission) ProtoMessage() {}

func (x *IAMPermission) ProtoReflect() protoreflect.Message {
	mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[2]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use IAMPermission.ProtoReflect.Descriptor instead.
func (*IAMPermission) Descriptor() ([]byte, []int) {
	return file_integration_common_shared_protos_status_status_proto_rawDescGZIP(), []int{2}
}

func (x *IAMPermission) GetName() string {
	if x != nil {
		return x.Name
	}
	return ""
}

func (x *IAMPermission) GetGranted() State {
	if x != nil {
		return x.Granted
	}
	return State_UNSPECIFIED_STATE
}

type ConfigValue struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Name      string `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Value     string `protobuf:"bytes,2,opt,name=value,proto3" json:"value,omitempty"`
	IsDefault bool   `protobuf:"varint,3,opt,name=is_default,json=isDefault,proto3" json:"is_default,omitempty"`
}

func (x *ConfigValue) Reset() {
	*x = ConfigValue{}
	if protoimpl.UnsafeEnabled {
		mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[3]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *ConfigValue) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*ConfigValue) ProtoMessage() {}

func (x *ConfigValue) ProtoReflect() protoreflect.Message {
	mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[3]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use ConfigValue.ProtoReflect.Descriptor instead.
func (*ConfigValue) Descriptor() ([]byte, []int) {
	return file_integration_common_shared_protos_status_status_proto_rawDescGZIP(), []int{3}
}

func (x *ConfigValue) GetName() string {
	if x != nil {
		return x.Name
	}
	return ""
}

func (x *ConfigValue) GetValue() string {
	if x != nil {
		return x.Value
	}
	return ""
}

func (x *ConfigValue) GetIsDefault() bool {
	if x != nil {
		return x.IsDefault
	}
	return false
}

type Reference struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Name string `protobuf:"bytes,1,opt,name=name,proto3" json:"name,omitempty"`
	Url  string `protobuf:"bytes,2,opt,name=url,proto3" json:"url,omitempty"`
}

func (x *Reference) Reset() {
	*x = Reference{}
	if protoimpl.UnsafeEnabled {
		mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[4]
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		ms.StoreMessageInfo(mi)
	}
}

func (x *Reference) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*Reference) ProtoMessage() {}

func (x *Reference) ProtoReflect() protoreflect.Message {
	mi := &file_integration_common_shared_protos_status_status_proto_msgTypes[4]
	if protoimpl.UnsafeEnabled && x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use Reference.ProtoReflect.Descriptor instead.
func (*Reference) Descriptor() ([]byte, []int) {
	return file_integration_common_shared_protos_status_status_proto_rawDescGZIP(), []int{4}
}

func (x *Reference) GetName() string {
	if x != nil {
		return x.Name
	}
	return ""
}

func (x *Reference) GetUrl() string {
	if x != nil {
		return x.Url
	}
	return ""
}

var File_integration_common_shared_protos_status_status_proto protoreflect.FileDescriptor

var file_integration_common_shared_protos_status_status_proto_rawDesc = []byte{
	0x0a, 0x34, 0x69, 0x6e, 0x74, 0x65, 0x67, 0x72, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x2f, 0x63, 0x6f,
	0x6d, 0x6d, 0x6f, 0x6e, 0x2f, 0x73, 0x68, 0x61, 0x72, 0x65, 0x64, 0x2f, 0x70, 0x72, 0x6f, 0x74,
	0x6f, 0x73, 0x2f, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x2f, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73,
	0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x1a, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x70, 0x61,
	0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73, 0x74, 0x61, 0x74,
	0x75, 0x73, 0x22, 0x96, 0x05, 0x0a, 0x0b, 0x41, 0x67, 0x65, 0x6e, 0x74, 0x53, 0x74, 0x61, 0x74,
	0x75, 0x73, 0x12, 0x2b, 0x0a, 0x11, 0x69, 0x6e, 0x73, 0x74, 0x61, 0x6c, 0x6c, 0x65, 0x64, 0x5f,
	0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x10, 0x69,
	0x6e, 0x73, 0x74, 0x61, 0x6c, 0x6c, 0x65, 0x64, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x12,
	0x2b, 0x0a, 0x11, 0x61, 0x76, 0x61, 0x69, 0x6c, 0x61, 0x62, 0x6c, 0x65, 0x5f, 0x76, 0x65, 0x72,
	0x73, 0x69, 0x6f, 0x6e, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x10, 0x61, 0x76, 0x61, 0x69,
	0x6c, 0x61, 0x62, 0x6c, 0x65, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x12, 0x59, 0x0a, 0x17,
	0x73, 0x79, 0x73, 0x74, 0x65, 0x6d, 0x64, 0x5f, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x5f,
	0x65, 0x6e, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x18, 0x03, 0x20, 0x01, 0x28, 0x0e, 0x32, 0x21, 0x2e,
	0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67,
	0x77, 0x61, 0x70, 0x2e, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x2e, 0x53, 0x74, 0x61, 0x74, 0x65,
	0x52, 0x15, 0x73, 0x79, 0x73, 0x74, 0x65, 0x6d, 0x64, 0x53, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65,
	0x45, 0x6e, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x12, 0x59, 0x0a, 0x17, 0x73, 0x79, 0x73, 0x74, 0x65,
	0x6d, 0x64, 0x5f, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x5f, 0x72, 0x75, 0x6e, 0x6e, 0x69,
	0x6e, 0x67, 0x18, 0x04, 0x20, 0x01, 0x28, 0x0e, 0x32, 0x21, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64,
	0x2e, 0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73,
	0x74, 0x61, 0x74, 0x75, 0x73, 0x2e, 0x53, 0x74, 0x61, 0x74, 0x65, 0x52, 0x15, 0x73, 0x79, 0x73,
	0x74, 0x65, 0x6d, 0x64, 0x53, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x52, 0x75, 0x6e, 0x6e, 0x69,
	0x6e, 0x67, 0x12, 0x36, 0x0a, 0x17, 0x63, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x75, 0x72, 0x61, 0x74,
	0x69, 0x6f, 0x6e, 0x5f, 0x66, 0x69, 0x6c, 0x65, 0x5f, 0x70, 0x61, 0x74, 0x68, 0x18, 0x05, 0x20,
	0x01, 0x28, 0x09, 0x52, 0x15, 0x63, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x75, 0x72, 0x61, 0x74, 0x69,
	0x6f, 0x6e, 0x46, 0x69, 0x6c, 0x65, 0x50, 0x61, 0x74, 0x68, 0x12, 0x52, 0x0a, 0x13, 0x63, 0x6f,
	0x6e, 0x66, 0x69, 0x67, 0x75, 0x72, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x5f, 0x76, 0x61, 0x6c, 0x69,
	0x64, 0x18, 0x06, 0x20, 0x01, 0x28, 0x0e, 0x32, 0x21, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e,
	0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73, 0x74,
	0x61, 0x74, 0x75, 0x73, 0x2e, 0x53, 0x74, 0x61, 0x74, 0x65, 0x52, 0x12, 0x63, 0x6f, 0x6e, 0x66,
	0x69, 0x67, 0x75, 0x72, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x56, 0x61, 0x6c, 0x69, 0x64, 0x12, 0x3e,
	0x0a, 0x1b, 0x63, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x75, 0x72, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x5f,
	0x65, 0x72, 0x72, 0x6f, 0x72, 0x5f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x18, 0x07, 0x20,
	0x01, 0x28, 0x09, 0x52, 0x19, 0x63, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x75, 0x72, 0x61, 0x74, 0x69,
	0x6f, 0x6e, 0x45, 0x72, 0x72, 0x6f, 0x72, 0x4d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x12, 0x45,
	0x0a, 0x08, 0x73, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x73, 0x18, 0x08, 0x20, 0x03, 0x28, 0x0b,
	0x32, 0x29, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72,
	0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x2e, 0x53, 0x65,
	0x72, 0x76, 0x69, 0x63, 0x65, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x08, 0x73, 0x65, 0x72,
	0x76, 0x69, 0x63, 0x65, 0x73, 0x12, 0x45, 0x0a, 0x0a, 0x72, 0x65, 0x66, 0x65, 0x72, 0x65, 0x6e,
	0x63, 0x65, 0x73, 0x18, 0x09, 0x20, 0x03, 0x28, 0x0b, 0x32, 0x25, 0x2e, 0x63, 0x6c, 0x6f, 0x75,
	0x64, 0x2e, 0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e,
	0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x2e, 0x52, 0x65, 0x66, 0x65, 0x72, 0x65, 0x6e, 0x63, 0x65,
	0x52, 0x0a, 0x72, 0x65, 0x66, 0x65, 0x72, 0x65, 0x6e, 0x63, 0x65, 0x73, 0x12, 0x1d, 0x0a, 0x0a,
	0x61, 0x67, 0x65, 0x6e, 0x74, 0x5f, 0x6e, 0x61, 0x6d, 0x65, 0x18, 0x0a, 0x20, 0x01, 0x28, 0x09,
	0x52, 0x09, 0x61, 0x67, 0x65, 0x6e, 0x74, 0x4e, 0x61, 0x6d, 0x65, 0x22, 0xd2, 0x02, 0x0a, 0x0d,
	0x53, 0x65, 0x72, 0x76, 0x69, 0x63, 0x65, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x12, 0x12, 0x0a,
	0x04, 0x6e, 0x61, 0x6d, 0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x04, 0x6e, 0x61, 0x6d,
	0x65, 0x12, 0x18, 0x0a, 0x07, 0x65, 0x6e, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x18, 0x02, 0x20, 0x01,
	0x28, 0x08, 0x52, 0x07, 0x65, 0x6e, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x12, 0x4c, 0x0a, 0x10, 0x66,
	0x75, 0x6c, 0x6c, 0x79, 0x5f, 0x66, 0x75, 0x6e, 0x63, 0x74, 0x69, 0x6f, 0x6e, 0x61, 0x6c, 0x18,
	0x03, 0x20, 0x01, 0x28, 0x0e, 0x32, 0x21, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x70, 0x61,
	0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73, 0x74, 0x61, 0x74,
	0x75, 0x73, 0x2e, 0x53, 0x74, 0x61, 0x74, 0x65, 0x52, 0x0f, 0x66, 0x75, 0x6c, 0x6c, 0x79, 0x46,
	0x75, 0x6e, 0x63, 0x74, 0x69, 0x6f, 0x6e, 0x61, 0x6c, 0x12, 0x23, 0x0a, 0x0d, 0x65, 0x72, 0x72,
	0x6f, 0x72, 0x5f, 0x6d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x18, 0x04, 0x20, 0x01, 0x28, 0x09,
	0x52, 0x0c, 0x65, 0x72, 0x72, 0x6f, 0x72, 0x4d, 0x65, 0x73, 0x73, 0x61, 0x67, 0x65, 0x12, 0x52,
	0x0a, 0x0f, 0x69, 0x61, 0x6d, 0x5f, 0x70, 0x65, 0x72, 0x6d, 0x69, 0x73, 0x73, 0x69, 0x6f, 0x6e,
	0x73, 0x18, 0x05, 0x20, 0x03, 0x28, 0x0b, 0x32, 0x29, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e,
	0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73, 0x74,
	0x61, 0x74, 0x75, 0x73, 0x2e, 0x49, 0x41, 0x4d, 0x50, 0x65, 0x72, 0x6d, 0x69, 0x73, 0x73, 0x69,
	0x6f, 0x6e, 0x52, 0x0e, 0x69, 0x61, 0x6d, 0x50, 0x65, 0x72, 0x6d, 0x69, 0x73, 0x73, 0x69, 0x6f,
	0x6e, 0x73, 0x12, 0x4c, 0x0a, 0x0d, 0x63, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x5f, 0x76, 0x61, 0x6c,
	0x75, 0x65, 0x73, 0x18, 0x06, 0x20, 0x03, 0x28, 0x0b, 0x32, 0x27, 0x2e, 0x63, 0x6c, 0x6f, 0x75,
	0x64, 0x2e, 0x70, 0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e,
	0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x2e, 0x43, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x56, 0x61, 0x6c,
	0x75, 0x65, 0x52, 0x0c, 0x63, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x56, 0x61, 0x6c, 0x75, 0x65, 0x73,
	0x22, 0x60, 0x0a, 0x0d, 0x49, 0x41, 0x4d, 0x50, 0x65, 0x72, 0x6d, 0x69, 0x73, 0x73, 0x69, 0x6f,
	0x6e, 0x12, 0x12, 0x0a, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52,
	0x04, 0x6e, 0x61, 0x6d, 0x65, 0x12, 0x3b, 0x0a, 0x07, 0x67, 0x72, 0x61, 0x6e, 0x74, 0x65, 0x64,
	0x18, 0x03, 0x20, 0x01, 0x28, 0x0e, 0x32, 0x21, 0x2e, 0x63, 0x6c, 0x6f, 0x75, 0x64, 0x2e, 0x70,
	0x61, 0x72, 0x74, 0x6e, 0x65, 0x72, 0x73, 0x2e, 0x67, 0x77, 0x61, 0x70, 0x2e, 0x73, 0x74, 0x61,
	0x74, 0x75, 0x73, 0x2e, 0x53, 0x74, 0x61, 0x74, 0x65, 0x52, 0x07, 0x67, 0x72, 0x61, 0x6e, 0x74,
	0x65, 0x64, 0x22, 0x56, 0x0a, 0x0b, 0x43, 0x6f, 0x6e, 0x66, 0x69, 0x67, 0x56, 0x61, 0x6c, 0x75,
	0x65, 0x12, 0x12, 0x0a, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x18, 0x01, 0x20, 0x01, 0x28, 0x09, 0x52,
	0x04, 0x6e, 0x61, 0x6d, 0x65, 0x12, 0x14, 0x0a, 0x05, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x18, 0x02,
	0x20, 0x01, 0x28, 0x09, 0x52, 0x05, 0x76, 0x61, 0x6c, 0x75, 0x65, 0x12, 0x1d, 0x0a, 0x0a, 0x69,
	0x73, 0x5f, 0x64, 0x65, 0x66, 0x61, 0x75, 0x6c, 0x74, 0x18, 0x03, 0x20, 0x01, 0x28, 0x08, 0x52,
	0x09, 0x69, 0x73, 0x44, 0x65, 0x66, 0x61, 0x75, 0x6c, 0x74, 0x22, 0x31, 0x0a, 0x09, 0x52, 0x65,
	0x66, 0x65, 0x72, 0x65, 0x6e, 0x63, 0x65, 0x12, 0x12, 0x0a, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x18,
	0x01, 0x20, 0x01, 0x28, 0x09, 0x52, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x12, 0x10, 0x0a, 0x03, 0x75,
	0x72, 0x6c, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x03, 0x75, 0x72, 0x6c, 0x2a, 0x55, 0x0a,
	0x05, 0x53, 0x74, 0x61, 0x74, 0x65, 0x12, 0x15, 0x0a, 0x11, 0x55, 0x4e, 0x53, 0x50, 0x45, 0x43,
	0x49, 0x46, 0x49, 0x45, 0x44, 0x5f, 0x53, 0x54, 0x41, 0x54, 0x45, 0x10, 0x00, 0x12, 0x11, 0x0a,
	0x0d, 0x53, 0x55, 0x43, 0x43, 0x45, 0x53, 0x53, 0x5f, 0x53, 0x54, 0x41, 0x54, 0x45, 0x10, 0x01,
	0x12, 0x11, 0x0a, 0x0d, 0x46, 0x41, 0x49, 0x4c, 0x55, 0x52, 0x45, 0x5f, 0x53, 0x54, 0x41, 0x54,
	0x45, 0x10, 0x02, 0x12, 0x0f, 0x0a, 0x0b, 0x45, 0x52, 0x52, 0x4f, 0x52, 0x5f, 0x53, 0x54, 0x41,
	0x54, 0x45, 0x10, 0x03, 0x42, 0x0a, 0x5a, 0x08, 0x2e, 0x2f, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73,
	0x62, 0x06, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x33,
}

var (
	file_integration_common_shared_protos_status_status_proto_rawDescOnce sync.Once
	file_integration_common_shared_protos_status_status_proto_rawDescData = file_integration_common_shared_protos_status_status_proto_rawDesc
)

func file_integration_common_shared_protos_status_status_proto_rawDescGZIP() []byte {
	file_integration_common_shared_protos_status_status_proto_rawDescOnce.Do(func() {
		file_integration_common_shared_protos_status_status_proto_rawDescData = protoimpl.X.CompressGZIP(file_integration_common_shared_protos_status_status_proto_rawDescData)
	})
	return file_integration_common_shared_protos_status_status_proto_rawDescData
}

var file_integration_common_shared_protos_status_status_proto_enumTypes = make([]protoimpl.EnumInfo, 1)
var file_integration_common_shared_protos_status_status_proto_msgTypes = make([]protoimpl.MessageInfo, 5)
var file_integration_common_shared_protos_status_status_proto_goTypes = []interface{}{
	(State)(0),            // 0: cloud.partners.gwap.status.State
	(*AgentStatus)(nil),   // 1: cloud.partners.gwap.status.AgentStatus
	(*ServiceStatus)(nil), // 2: cloud.partners.gwap.status.ServiceStatus
	(*IAMPermission)(nil), // 3: cloud.partners.gwap.status.IAMPermission
	(*ConfigValue)(nil),   // 4: cloud.partners.gwap.status.ConfigValue
	(*Reference)(nil),     // 5: cloud.partners.gwap.status.Reference
}
var file_integration_common_shared_protos_status_status_proto_depIdxs = []int32{
	0, // 0: cloud.partners.gwap.status.AgentStatus.systemd_service_enabled:type_name -> cloud.partners.gwap.status.State
	0, // 1: cloud.partners.gwap.status.AgentStatus.systemd_service_running:type_name -> cloud.partners.gwap.status.State
	0, // 2: cloud.partners.gwap.status.AgentStatus.configuration_valid:type_name -> cloud.partners.gwap.status.State
	2, // 3: cloud.partners.gwap.status.AgentStatus.services:type_name -> cloud.partners.gwap.status.ServiceStatus
	5, // 4: cloud.partners.gwap.status.AgentStatus.references:type_name -> cloud.partners.gwap.status.Reference
	0, // 5: cloud.partners.gwap.status.ServiceStatus.fully_functional:type_name -> cloud.partners.gwap.status.State
	3, // 6: cloud.partners.gwap.status.ServiceStatus.iam_permissions:type_name -> cloud.partners.gwap.status.IAMPermission
	4, // 7: cloud.partners.gwap.status.ServiceStatus.config_values:type_name -> cloud.partners.gwap.status.ConfigValue
	0, // 8: cloud.partners.gwap.status.IAMPermission.granted:type_name -> cloud.partners.gwap.status.State
	9, // [9:9] is the sub-list for method output_type
	9, // [9:9] is the sub-list for method input_type
	9, // [9:9] is the sub-list for extension type_name
	9, // [9:9] is the sub-list for extension extendee
	0, // [0:9] is the sub-list for field type_name
}

func init() { file_integration_common_shared_protos_status_status_proto_init() }
func file_integration_common_shared_protos_status_status_proto_init() {
	if File_integration_common_shared_protos_status_status_proto != nil {
		return
	}
	if !protoimpl.UnsafeEnabled {
		file_integration_common_shared_protos_status_status_proto_msgTypes[0].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*AgentStatus); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
		file_integration_common_shared_protos_status_status_proto_msgTypes[1].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*ServiceStatus); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
		file_integration_common_shared_protos_status_status_proto_msgTypes[2].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*IAMPermission); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
		file_integration_common_shared_protos_status_status_proto_msgTypes[3].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*ConfigValue); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
		file_integration_common_shared_protos_status_status_proto_msgTypes[4].Exporter = func(v interface{}, i int) interface{} {
			switch v := v.(*Reference); i {
			case 0:
				return &v.state
			case 1:
				return &v.sizeCache
			case 2:
				return &v.unknownFields
			default:
				return nil
			}
		}
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: file_integration_common_shared_protos_status_status_proto_rawDesc,
			NumEnums:      1,
			NumMessages:   5,
			NumExtensions: 0,
			NumServices:   0,
		},
		GoTypes:           file_integration_common_shared_protos_status_status_proto_goTypes,
		DependencyIndexes: file_integration_common_shared_protos_status_status_proto_depIdxs,
		EnumInfos:         file_integration_common_shared_protos_status_status_proto_enumTypes,
		MessageInfos:      file_integration_common_shared_protos_status_status_proto_msgTypes,
	}.Build()
	File_integration_common_shared_protos_status_status_proto = out.File
	file_integration_common_shared_protos_status_status_proto_rawDesc = nil
	file_integration_common_shared_protos_status_status_proto_goTypes = nil
	file_integration_common_shared_protos_status_status_proto_depIdxs = nil
}
