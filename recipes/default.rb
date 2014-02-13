#
# Cookbook Name:: ec2-dns-server
# Recipe:: default
#
# Copyright (C) 2013 EverTrue, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe "et_fog"
include_recipe "ec2dnsserver::#{node['ec2dnsserver']['log']['logger']}"

package "bind9"

execute "reload_zones" do
  command "rndc reload"
  action :nothing
end

service node['ec2dnsserver']['service_name'] do
  supports :status => true, :restart => true, :reload => true
  action :nothing
end

# The following should really only be necessary to get this to
# converge on a vagrant box.
directory "/etc/dhcp/dhclient-exit-hooks.d" do
  owner "root"
  group "root"
  mode 00755
  action :create
  recursive true
  not_if { node['ec2'] }
end

template "/etc/dhcp/dhclient-exit-hooks.d/set-bind-forwarders" do
  source "set-bind-forwarders.erb"
  owner "root"
  group "root"
  mode 00644
end

template "#{node['ec2dnsserver']['config_dir']}/named.conf.options" do
  source "named.conf.options.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
end

template "#{node['ec2dnsserver']['config_dir']}/named.conf.local" do
  source "named.conf.local.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[#{node['ec2dnsserver']['service_name']}]"
end

node['ec2dnsserver']['zones'].each do |zone,zone_conf|
  ec2dnsserver_zone zone do
    vpc node['ec2dnsserver']['vpc']
    ptr zone_conf['ptr_zone']
    suffix zone_conf['suffix']
    static_records zone_conf['static_records']
    avoid_subnets node['ec2dnsserver']['avoid_subnets']
    contact_email node['ec2dnsserver']['contact_email']
    path "#{node['ec2dnsserver']['zones_dir']}/db.#{zone}"
    notifies :run, "execute[reload_zones]"
  end
end

init_config_file = value_for_platform(
  ['ubuntu','debian'] => {"default" => "/etc/default/bind9"},
  ["centos", "redhat", "suse", "fedora", "amazon", "amazonaws"] => {
    "default" => "/etc/sysconfig/named"
  }
)

file init_config_file do
  if node['ec2dnsserver']['enable-ipv6']
    content "RESOLVCONF=no\nOPTIONS=-u bind\n"
  else
    content "RESOLVCONF=no\nOPTIONS=\"-u bind -4\n\""
  end
end

template "/etc/logrotate.d/named" do
  source "logrotate.conf.erb"
  owner "root"
  group "root"
  mode 00644
end
