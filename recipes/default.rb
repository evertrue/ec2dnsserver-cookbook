#
# Cookbook Name:: ec2-dns-server
# Recipe:: default
#
# Copyright (C) 2013 EverTrue, Inc.
# 
# All rights reserved - Do Not Redistribute
#
include_recipe "ec2dnsserver::fog"
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

node['ec2dnsserver']['zones'].each do |zone|
  ec2dnsserver_zone zone['apex'] do
    vpc node['ec2dnsserver']['vpc']
    ptr zone['ptr_zone']
    suffix zone['suffix']
    contact_email node['ec2dnsserver']['contact_email']
    path "#{node['ec2dnsserver']['zones_dir']}/db.#{zone['apex']}"
    notifies :run, "execute[reload_zones]"
  end
end

template "/etc/logrotate.d/named" do
  source "logrotate.conf.erb"
  owner "root"
  group "root"
  mode 00644
end
