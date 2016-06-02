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
