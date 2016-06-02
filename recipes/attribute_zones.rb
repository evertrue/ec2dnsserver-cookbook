#
# Cookbook Name:: ec2dnsserver
# Recipe:: attribute_zones
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

node['ec2dnsserver']['zones'].each do |zone, zone_conf|
  Chef::Log.info("Zone #{zone} using suffix #{zone_conf['suffix']}") if zone_conf['suffix']

  ec2dnsserver_zone zone do
    vpcs zone_conf['vpcs'] if zone_conf['vpcs']
    stub zone_conf['stub'] if zone_conf['stub']
    ptr zone_conf['ptr_zone'] unless zone_conf['ptr_zone'].nil?
    suffix zone_conf['suffix'] if zone_conf['suffix']
    ns_zone zone_conf['ns_zone'] if zone_conf['ns_zone']
    static_records zone_conf['static_records'] if zone_conf['static_records']
    avoid_subnets node['ec2dnsserver']['avoid_subnets']
    contact_email node['ec2dnsserver']['contact_email']
    notifies :run, 'execute[reload_zones]'
  end
end
