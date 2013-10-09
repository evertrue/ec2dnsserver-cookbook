class Chef::Recipe::Ec2DnsServer

  def self.valid_hostname?(hostname)

    if hostname.length > 255 or hostname.scan('..').any?
      return false
    end

    if hostname.index('.', -1)
      hostname = hostname[0 ... -1]
    end

    return hostname.split('.').collect { |i|
      i.size <= 63 and not
        (i.rindex('-', 0) or
          i.index('-', -1) or
          i.scan(/[^a-z\d-]/i).any?
        )
    }.all?

  end

  def get_names_with_ips(vpc = nil, avoid_subnets = [])

    require 'fog'

    aws_keys = Chef::EncryptedDataBagItem.load("secrets","aws_credentials")[@node['ec2dnsserver']['aws_api_user']]

    conn = Fog::Compute.new(
      :provider => "AWS",
      :aws_access_key_id => aws_keys['access_key_id'],
      :aws_secret_access_key => aws_keys['secret_access_key']
    )

    Chef::Log.info("Avoiding these subnets: #{avoid_subnets.join(',')}")

    filter = { 'vpc-id' => vpc } if vpc

    h = Hash.new
    conn.servers.all(filter).map do |s|
      if s.tags["Name"]
        h[s.tags["Name"]] = s.network_interfaces.reject { |ni|
          avoid_subnets.include?ni["subnetId"]}.reject { |ni|
            ni == {}
          }.map { |ni|
            conn.network_interfaces.get(ni["networkInterfaceId"]).private_ip_address
          }.first || s.private_ip_address
      end
    end

    h

  end

  def initialize(node)
    @node = node
  end

end
