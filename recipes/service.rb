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
