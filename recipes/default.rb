#
# Cookbook Name:: ec2-dns-server
# Recipe:: default
#
# Copyright (C) 2013 EverTrue, Inc.
#
# All rights reserved - Do Not Redistribute
#

fail 'This cookbook will only work on nodes in ec2' unless node['ec2']

include_recipe 'et_fog'
include_recipe "ec2dnsserver::#{node['ec2dnsserver']['log']['logger']}"

package 'bind9'

execute 'reload_zones' do
  command 'rndc reload'
  action :nothing
end

service node['ec2dnsserver']['service_name'] do
  supports status: true, restart: true, reload: true
  action :nothing
end

# The following should really only be necessary to get this to
# converge on a vagrant box.
directory '/etc/dhcp/dhclient-exit-hooks.d' do
  owner 'root'
  group 'root'
  mode 00755
  action :create
  recursive true
  not_if { node['ec2'] }
end

template '/etc/dhcp/dhclient-exit-hooks.d/set-bind-forwarders' do
  source 'set-bind-forwarders.erb'
  owner 'root'
  group 'root'
  mode 00644
end

log "ec2 hash: #{node['ec2'].inspect}" do
  level :info
end.run_action(:write)

forwarders = Ec2DnsServer.forwarders(node)

Chef::Log.info("Forwarders: #{forwarders}")

template "#{node['ec2dnsserver']['config_dir']}/named.conf.options" do
  source 'named.conf.options.erb'
  owner 'root'
  group 'root'
  mode 00644
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
  variables(forwarders: forwarders)
end

template "#{node['ec2dnsserver']['config_dir']}/named.conf.local" do
  source 'named.conf.local.erb'
  owner 'root'
  group 'root'
  mode 00644
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
end

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
end

template '/etc/logrotate.d/named' do
  source 'logrotate.conf.erb'
  owner 'root'
  group 'root'
  mode 00644
end
