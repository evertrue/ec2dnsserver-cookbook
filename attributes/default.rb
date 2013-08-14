# Update the chef-client refresh interval so that find new nodes pretty
# promptly after they're spun up.
set["chef_client"]["interval"] = "300"
set["chef_client"]["splay"] = "180"

default['ec2dnsserver']['aws_api_user'] = "Ec2DnsServer"
default['ec2dnsserver']['vpc'] = nil
default['ec2dnsserver']['config_dir'] = "/etc/bind"
default['ec2dnsserver']['cache_dir'] = "/var/cache/bind"
default['ec2dnsserver']['forwarders'] = []
default['ec2dnsserver']['zones_dir'] = node['ec2dnsserver']['config_dir']
default['ec2dnsserver']['contact_email'] = "hostmaster@evertrue.com"
default['ec2dnsserver']['enable-ipv6'] = false
default['ec2dnsserver']['dnssec_validation'] = "no"
default['ec2dnsserver']['log']['log_queries'] = false
default['ec2dnsserver']['log']['facility'] = "daemon"
default['ec2dnsserver']['log']['versions'] = "5"
default['ec2dnsserver']['log']['size'] = "25M"
default['ec2dnsserver']['log']['logger'] = "rsyslog"
default['ec2dnsserver']['log']['severity'] = "dynamic"
default['ec2dnsserver']['log']['file'] = "/var/log/named/named.log"
default['ec2dnsserver']['config_path'] = node['ec2dnsserver']['config_dir'] + "/named.conf"
default['ec2dnsserver']['service_name'] = value_for_platform(
  ['ubuntu','debian'] => {"default" => "bind9"},
  ["centos", "redhat", "suse", "fedora", "amazon", "amazonaws"] => {
    "default" => "named"
  }
)
default['ec2dnsserver']['zones'] = []
