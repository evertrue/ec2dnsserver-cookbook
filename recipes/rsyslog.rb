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
