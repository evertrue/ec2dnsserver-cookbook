#
# Cookbook Name:: ec2dnsserver
# Recipe:: service
#
# Copyright 2015 EverTrue, Inc.
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

service node['ec2dnsserver']['service_name'] do
  supports status: true, restart: true, reload: true
  action :nothing
end

init_config_file = value_for_platform(
  %w(ubuntu debian) => { 'default' => '/etc/default/bind9' },
  %w(centos redhat suse fedora amazon amazonaws) => {
    'default' => '/etc/sysconfig/named'
  }
)

file init_config_file do
  if node['ec2dnsserver']['enable-ipv6']
    content "RESOLVCONF=no\nOPTIONS=-u bind\n"
  else
    content "RESOLVCONF=no\nOPTIONS=\"-u bind -4\n\""
  end
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
end
