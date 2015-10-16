#
# Cookbook Name:: ec2dnsserver
# Recipe:: default
#
# Copyright 2013 EverTrue, Inc.
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

fail 'This cookbook will only work on nodes in ec2' unless node['ec2']

package 'bind9'

include_recipe 'et_fog'
include_recipe "ec2dnsserver::#{node['ec2dnsserver']['log']['logger']}"

execute 'reload_zones' do
  command 'rndc reload'
  action :nothing
end

include_recipe 'ec2dnsserver::service'

file '/etc/dhcp/dhclient-exit-hooks.d/set-bind-forwarders' do
  action :delete
end

log "ec2 hash: #{node['ec2'].inspect}" do
  level :info
end.run_action(:write)

include_recipe 'ec2dnsserver::conf'
include_recipe 'ec2dnsserver::attribute_zones' if node['ec2dnsserver']['zones'].any?

template '/etc/logrotate.d/named' do
  source 'logrotate.conf.erb'
  owner 'root'
  group 'root'
  mode 00644
end
