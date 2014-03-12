class Chef::Recipe::Ec2DnsServer
  def self.valid_hostname?(hostname)
    return false if hostname.length > 255 || hostname.scan('..').any?

    hostname = hostname[0 ... -1] if hostname.index('.', -1)

    hostname.split('.').map do |i|
      i.size <= 63 && !(i.rindex('-', 0) ||
        i.index('-', -1) ||
        i.scan(/[^a-z\d-]/i).any?
      )
    end.all?
  end

  def vpc_default_dns(vpc_id)
    # Currently assume the default DNS server is second valid IP in the VPC
    # subnet (the first is usually the gateway).  Suggestions for a more
    # "correct" way to get the default DNS are welcome/encouraged.

    vpc_net = connection.vpcs.all('vpc-id' => vpc_id).first.cidr_block
    IPAddress::IPv4.parse_u32(IPAddress.parse(vpc_net).network_u32 + 2)
  end

  def chef_nodename(static_records = {})
    # The purpose of this clunky function is to provide, essentially, DNS
    # overrides.
    #
    # This method builds a hash (compatible with the parser we use in the
    # zone template) containing the RR and value for nodes (or whatever)
    # specified using the static_records attribute.

    h = {}

    static_records.each do |rr, rr_data|
      begin
        Chef::Log.debug("Processing static record: #{rr_data.class}/#{rr}/#{rr_data.inspect}")

        if rr_data.class == String
          h[rr] = { 'val' => rr_data }
        elsif rr_data['cookbook']
          result = Chef::Search::Query.new.search(
              :node,
              "chef_environment:#{@env} AND " +
              "recipes:#{rr_data['cookbook']}"
            ).first.first

          fail "No nodes found with cookbook #{rr_data['cookbook']}" if result.nil?

          h[rr] = { 'val' => result.name }
        elsif rr_data['role']
          result = Chef::Search::Query.new.search(
              :node,
              "chef_environment:#{@env} AND " +
              "roles:#{rr_data['role']}"
            ).first.first

          fail "No nodes found with role #{rr_data['role']}" if result.nil?

          h[rr] = { 'val' => result.name }
        else
          fail "No recognized static record data: #{rr_data.inspect}"
        end
        h[rr]['type'] = 'CNAME'
      end
    end

    h
  end

  def connection
    @connection ||= begin
      require 'fog'

      aws_keys = Chef::EncryptedDataBagItem.load(
        'secrets',
        'aws_credentials'
      )[@node['ec2dnsserver']['aws_api_user']]

      @connnection = Fog::Compute.new(
        provider: 'AWS',
        aws_access_key_id: aws_keys['access_key_id'],
        aws_secret_access_key: aws_keys['secret_access_key']
      )
    end
  end

  def ec2_servers(filter = {})
    connection.servers.all(filter)
  end

  def ec2_network_interfaces(filter = {})
    connection.network_interfaces.all(filter)
  end

  def get_names_with_ips(options = {})
    filter = { 'vpc-id' => options['vpc-id'] } if options['vpc-id']
    avoid_subnets = options['avoid_subnets'] || []

    unless avoid_subnets == []
      Chef::Log.info("Avoiding these subnets: #{options['avoid_subnets'].join(',')}")
    end

    h = {}

    ec2_servers(filter).map do |s|
      if s.tags['Name']
        h[s.tags['Name']] = {
          'type' => 'A',
          'val' => s.network_interfaces.reject { |ni|
              avoid_subnets.include?ni['subnetId']
            }.reject { |ni|
              ni == {}
            }.map { |ni|
              # Don't avoid an IP if it's the only IP.
              ec2_network_interfaces.get(ni['networkInterfaceId']).private_ip_address
            }.first || s.private_ip_address
        }
      end
    end

    h.merge!(chef_nodename((options['static_records'] || {})))

    h
  end

  def initialize(node = {}, env = '')
    @node = node
    @env = env
  end
end
