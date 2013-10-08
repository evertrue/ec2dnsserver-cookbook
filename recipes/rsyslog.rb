directory File.dirname(node['ec2dnsserver']['log']['file']) do
  group node['ec2dnsserver']['group']
  mode 00775
end

service "rsyslog" do
  supports :status => true, :restart => true
  action [ :enable, :start ]
end

template "/etc/rsyslog.d/25-named.conf" do
  source "rsyslog.conf.erb"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[rsyslog]"
end
