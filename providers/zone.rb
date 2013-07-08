action :create do
  dns_server = Chef::Recipe::Ec2DnsServer.new(node)
  hosts = dns_server.get_names_with_ips(new_resource.vpc)

  # In the template, the source host and the apex are both supposed
  # to end with dots in SOME places in the template. We're not going 
  # to assume the recipe writer knows how we're going to deal with 
  # this, so we'll just always remove the dot and add it later if we 
  # need it.

  source_host = new_resource.source_host.sub(/\.$/,'')
  apex = new_resource.apex.sub(/\.$/,'')

  template new_resource.path do
    source "zone.erb"
    owner "root"
    group "root"
    mode 00644
    variables(
      :hosts => hosts,
      :apex => apex,
      :source_host => source_host,
      :ptr => new_resource.ptr,
      :suffix => new_resource.suffix,
      :serial_number => Time.now.to_i,
      :default_ttl => new_resource.default_ttl,
      :contact_email => new_resource.contact_email.sub("@","."),
      :refresh_time => new_resource.refresh_time,
      :retry_time => new_resource.retry_time,
      :expire_time => new_resource.expire_time,
      :min_ttl => new_resource.min_ttl
    )
  end

end

action :delete do
  file new_resource.path do
    action :delete
  end
end