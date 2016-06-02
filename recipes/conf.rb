#
# Cookbook Name:: ec2dnsserver
# Recipe:: conf
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

forwarders = Ec2DnsServer.forwarders node

Chef::Log.info "Forwarders: #{forwarders}"

template "#{node['ec2dnsserver']['config_dir']}/named.conf.options" do
  source 'named.conf.options.erb'
  owner 'root'
  group 'root'
  mode 00644
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
  variables(forwarders: forwarders)
end

template "#{node['ec2dnsserver']['config_dir']}/named.conf.local" do
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
  variables(
    zones: node['ec2dnsserver']['zones'].reject do |_zone, zone_conf|
      zone_conf['type'] && zone_conf['type'] != 'master'
    end
  )
end

template "#{node['ec2dnsserver']['config_dir']}/named.conf.remote" do
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
  variables(
    zones: node['ec2dnsserver']['zones'].select do |_zone, zone_conf|
      zone_conf['type'] &&
      %w(forward).include?(zone_conf['type'])
    end
  )
end

cookbook_file "#{node['ec2dnsserver']['config_dir']}/named.conf" do
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
end
