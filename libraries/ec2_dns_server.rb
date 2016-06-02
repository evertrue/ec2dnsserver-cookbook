class Chef::Recipe::Ec2DnsServer
  require 'ipaddress'

  attr_reader :apex, :env, :zone_options

  def self.forwarders(node)
    # This determines what our external DNS source is going to be.
    Chef::Log.debug "Contents of node['ec2']: #{node['ec2'].inspect}"
    if node['ec2dnsserver']['forwarders']
      # First try statically defined
      node['ec2dnsserver']['forwarders']
    elsif node['ec2']['network_interfaces_macs'][node['ec2']['mac'].downcase]['vpc_ipv4_cidr_block']
      # Next try to determine it programmatically based on our VPC subnet (if any)
      [
        Chef::Recipe::Ec2DnsServer.vpc_default_dns(
          node['ec2']['network_interfaces_macs'][node['ec2']['mac']]['vpc_ipv4_cidr_block']
        )
      ]
    else
      # This falls back to the EC2 global default
      ['10.0.0.2']
    end
  end

  def self.valid_hostname?(hostname)
    return false if hostname.length > 255 || hostname.scan('..').any?

    hostname = hostname[0...-1] if hostname.index('.', -1)

    hostname.split('.').map do |i|
      i.size <= 63 && !(
          i.rindex('-', 0) ||
          i.index('-', -1) ||
          i.scan(/[^a-z\d-]/i).any?
      )
    end.all?
  end

  def self.vpc_default_dns(vpc_net)
    # Currently assume the default DNS server is second valid IP in the VPC
    # subnet (the first is usually the gateway).  Suggestions for a more
    # "correct" way to get the default DNS are welcome/encouraged.

    IPAddress::IPv4.parse_u32(IPAddress.parse(vpc_net).network_u32 + 2).address
  end

  def initialize(env, apex, zone_options = {})
    @env = env
    @apex = apex
    @zone_options = zone_options
    @mocking = false
  end

  def hosts(is_stub, vpcs)
    if is_stub
      { 'stub' => override_record(zone_options['static_records']) }
    elsif vpcs.any?
      vpcs.each_with_object({}) do |vpc, m|
        m.merge! names_with_ips('vpc-id' => vpc)
      end
    else
      names_with_ips
    end
  end

  def mock!
    @mocking = true
  end

  private

  def mocking?
    @mocking
  end

  def names_with_ips(server_filter = {})
    h = ec2_servers(server_filter)
        .each_with_object({}) do |server, memo|
      next unless server.tags['Name'] &&
                  Chef::Recipe::Ec2DnsServer.valid_hostname?(server.tags['Name'])
      server_ip = server_obj_ip(server)
      next unless server_ip
      memo[server.tags['Name']] = {
        'type' => 'A',
        'val' => server_ip
      }
    end

    h.merge! override_records(zone_options['static_records'])

    Chef::Log.debug("Merged host hash for #{apex}: #{h.inspect}")

    h
  end

  def override_record(rr_data)
    if rr_data['value']
      fail "No record type specified for #{rr_data['value']}" unless rr_data['type']
      {
        'val' => rr_data['value'],
        'type' => rr_data['type']
      }
    elsif rr_data['cookbook'] || rr_data['role']
      n = node_by_search_data(rr_data)
      if rr_data['type'] && rr_data['type'] == 'CNAME'
        {
          'val' => n.name,
          'type' => 'CNAME'
        }
      else
        {
          'val' => n['ipaddress'],
          'type' => 'A'
        }
      end
    else
      fail "Unsupported record type: #{rr_data.inspect}"
    end
  end

  def node_by_search_data(rr_data)
    if rr_data['cookbook']
      result = Chef::Search::Query.new.search(
        :node,
        "chef_environment:#{env} AND " \
        "run_list:recipe\\[#{rr_data['cookbook']}\\]"
      ).first.first

      fail "No nodes found with cookbook #{rr_data['cookbook']}" if result.nil?

      return result
    elsif rr_data['role']
      result = Chef::Search::Query.new.search(
        :node,
        "chef_environment:#{env} AND " \
        "roles:#{rr_data['role']}"
      ).first.first

      fail "No nodes found with role #{rr_data['role']}" if result.nil?

      return result
    end
    fail "No recognized static record data: #{rr_data.inspect}"
  end

  def connection
    @connection ||= begin
      require 'fog'

      if @node['ec2dnsserver']['mocking']
        connection = mock_servers
      else

        Fog::Compute::AWS.new(
          zone_options[:conn_opts] || { use_iam_profile: true }
        )
      end
    end
  end

  def mock_servers
    Fog.mock!

    connection = Fog::Compute.new(
      provider: 'AWS',
      aws_access_key_id: '',
      aws_secret_access_key: ''
    )
    connection.vpcs.create cidr_block: '10.0.0.0/24'
    connection.subnets.create vpc_id: connection.vpcs.first.id, cidr_block: '10.0.0.0/24'
    connection.servers.create(
      tags: { Name: 'test-ops-haproxy-1b' },
      subnet_id: connection.subnets.first.subnet_id
    )

    connection
  end

  def ec2_servers(filter = {})
    connection.servers.all(filter)
  end

  def override_records(data = {})
    # The purpose of this clunky function is to provide, essentially, DNS
    # overrides.
    #
    # This method builds a hash (compatible with the parser we use in the
    # zone template) containing the RR and value for nodes (or whatever)
    # specified using the static_records attribute.

    return {} if data.nil?

    data.each_with_object({}) do |(rr, rr_data), m|
      Chef::Log.debug('Processing static record: ' \
        "#{rr_data.class}/#{rr}/#{rr_data.inspect}")
      m[rr] = override_record(rr_data)
    end
  end

  def non_public_interfaces(server)
    unless zone_options['avoid_subnets'] == []
      Chef::Log.info('Avoiding these subnets: ' +
        zone_options['avoid_subnets'].join(','))
    end

    server.network_interfaces.reject do |ni|
      zone_options['avoid_subnets'].include?(ni['subnetId']) || ni == {}
    end
  end

  def ec2_network_interfaces
    @ec2_network_interfaces ||= connection.network_interfaces
  end

  def server_obj_ip(server)
    ips = non_public_interfaces(server).map do |server_ni|
      ec2_network_interfaces.find do |global_ni|
        (global_ni.network_interface_id == server_ni['networkInterfaceId']) &&
        global_ni.private_ip_address
      end
    end

    ips.compact!

    return ips.sort_by { |ni| ni.attachment['deviceIndex'] }.first
      .private_ip_address unless ips.empty?

    # If there are no private IPs outside of avoided subnets, fall back to one
    # whatever we can find.
    return server.private_ip_address unless server.private_ip_address.nil?

    Chef::Log.warn("#{server.tags['Name']} has no private IP")
    false
  end
end
