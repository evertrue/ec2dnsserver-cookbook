#
# Cookbook Name:: ec2dnsserver
# Resource:: zone
#
# Copyright 2013, EverTrue, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

actions :create, :delete
default_action :create

attribute :apex,                  kind_of: String,            name_attribute: true
attribute :path,                  kind_of: String,            default: nil
attribute :suffix,                kind_of: String,            default: nil
attribute :source_host,           kind_of: String,            default: node.name
attribute :ptr,                   equal_to: [true, false],    default: false
attribute :default_ttl,           kind_of: Fixnum,            default: 300
attribute :contact_email,         kind_of: String,            required: true
attribute :refresh_time,          kind_of: [String, Fixnum],  default: '3600'
attribute :retry_time,            kind_of: [String, Fixnum],  default: '600'
attribute :expire_time,           kind_of: [String, Fixnum],  default: '86400'
attribute :nxdomain_ttl,          kind_of: [String, Fixnum],  default: '300'
attribute :vpcs,                  kind_of: Array,             default: []
attribute :static_records,        kind_of: Hash,              default: {}
attribute :avoid_subnets,         kind_of: Array,             default: []
attribute :stub,                  equal_to: [true, false],    default: false
attribute :ns_zone,               kind_of: String,            default: nil
attribute :aws_access_key_id,     kind_of: String
attribute :aws_secret_access_key, kind_of: String
attribute :mocking,               equal_to: [true, false],    default: false
