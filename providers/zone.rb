use_inline_resources

action :create do
  dns_server = Chef::Recipe::Ec2DnsServer.new(node, node.chef_environment)

  # In the template, the source host and the apex are both supposed
  # to end with dots in SOME places in the template. We're not going
  # to assume the recipe writer knows how we're going to deal with
  # this, so we'll just always remove the dot and add it later if we
  # need it.
  apex = new_resource.apex.sub(/\.$/, '')
  source_host = new_resource.source_host.sub(/\.$/, '')

  # We need a suffix but stub zones don't inherently have them
  if new_resource.suffix.empty? && new_resource.soa_zone.empty?
    fail "#{apex}: Either suffix or soa_zone must be specified"
  elsif !new_resource.suffix.empty?
    suffix = new_resource.suffix
    is_primary = true
  else
    suffix = new_resource.soa_zone
    is_primary = false
  end

  if new_resource.path.nil?
    path = "#{node['ec2dnsserver']['zones_dir']}/db.#{apex}"
  else
    path = new_resource.path
  end

  if !new_resource.vpcs.empty?
    hosts = {}

    new_resource.vpcs.each do |vpc|
      hosts.merge!(dns_server.get_names_with_ips(
        apex,
        new_resource.stub,
        'vpc-id' => vpc,
        'avoid_subnets' => new_resource.avoid_subnets,
        'static_records' => new_resource.static_records
      ))
    end
  else
    hosts = dns_server.get_names_with_ips(
      apex,
      new_resource.stub,
      'avoid_subnets' => new_resource.avoid_subnets,
      'static_records' => new_resource.static_records
    )
  end

  template path do
    source 'zone.erb'
    mode 00644
    group 'bind'
    variables(
      hosts: hosts,
      apex: apex,
      is_primary: is_primary,
      stub: new_resource.stub,
      source_host: source_host,
      ptr: new_resource.ptr,
      suffix: suffix,
      serial_number: Time.now.to_i,
      default_ttl: new_resource.default_ttl,
      contact_email: new_resource.contact_email.sub('@', '.'),
      refresh_time: new_resource.refresh_time,
      retry_time: new_resource.retry_time,
      expire_time: new_resource.expire_time,
      nxdomain_ttl: new_resource.nxdomain_ttl
    )
    action :nothing
  end

  directory "#{Chef::Config[:file_cache_path]}/ec2dnsserver/zones_without_serials" do
    owner 'root'
    group 'root'
    mode 00755
    action :create
    recursive true
  end

  # This next bit seems like a kludge (and it is) but the purpose of it
  # is to ONLY update the zone file when there is an actual zone
  # change (rather than every time chef-client runs), while still using
  # Time.now.to_i to generate the zone serial number.  Since we're
  # treating the serial number as a template variable, chef would normally
  # try to update this template (and thus the serial number) every time it
  # runs.  Instead we have a second "dummy" file tied to the same exact
  # same variables (minus the serial number) that notifies the "real"
  # template whenever it gets updated, and otherwise the real template
  # doesn't update (so the serial number doesn't change).
  # Nice, huh? ;-)
  #   -- devops@evertrue.com

  directory ::File.dirname("#{Chef::Config[:file_cache_path]}/ec2dnsserver/zones_without_serials" +
      path) do
    recursive true
  end

  template "#{Chef::Config[:file_cache_path]}/ec2dnsserver/zones_without_serials" + path do
    source 'zone.erb'
    mode 00644
    variables(
      hosts: hosts,
      apex: apex,
      is_primary: is_primary,
      stub: new_resource.stub,
      source_host: source_host,
      ptr: new_resource.ptr,
      suffix: suffix,
      serial_number: '',
      default_ttl: new_resource.default_ttl,
      contact_email: new_resource.contact_email.sub('@', '.'),
      refresh_time: new_resource.refresh_time,
      retry_time: new_resource.retry_time,
      expire_time: new_resource.expire_time,
      nxdomain_ttl: new_resource.nxdomain_ttl
    )
    notifies :create, "template[#{path}]"
  end

end

action :delete do
  file new_resource.path do
    action :delete
  end
end
