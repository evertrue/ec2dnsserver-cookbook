class Chef::Recipe::Ec2DnsServer
  require 'ipaddress'

  def self.forwarders(node)
    # This determines what our external DNS source is going to be.
    if node['ec2dnsserver']['forwarders']
      # First try statically defined
      node['ec2dnsserver']['forwarders']
    elsif node['ec2']['network_interfaces_macs'][node['ec2']['mac']]['vpc_ipv4_cidr_block']
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

    IPAddress::IPv4.parse_u32(IPAddress.parse(vpc_net).network_u32 + 2)
  end

  def get_names_with_ips(apex, stub, options = {})
    @apex = apex
    @stub = stub
    filter = {}
    filter['vpc-id'] = options['vpc-id'] if options['vpc-id']
    @avoid_subnets = options['avoid_subnets'] || []

    Chef::Log.info('Avoiding these subnets: ' +
      options['avoid_subnets'].join(',')) unless @avoid_subnets == []

    h = if @stub
          {}
        else
          ec2_servers(filter).each_with_object({}) do |server, memo|
            server_ip = server_obj_ip(server)
            next unless server_ip
            memo[server.tags['Name']] = {
              'type' => 'A',
              'val' => server_ip
            }
          end
        end

    h.merge!(
      static_record_nodenames(
        (options['static_records'] || {})
      )
    )

    Chef::Log.debug("Merged host hash for #{@apex}: #{h.inspect}")

    h
  end

  def initialize(node = {}, env = '')
    @node = node
    @env = env
  end

  private

  def node_by_search_data(rr_data)
    if rr_data['cookbook']
      result = Chef::Search::Query.new.search(
        :node,
        "chef_environment:#{@env} AND " \
        "run_list:recipe\\[#{rr_data['cookbook']}\\]"
      ).first.first

      fail "No nodes found with cookbook #{rr_data['cookbook']}" if result.nil?

      result.name
    elsif rr_data['value']
      rr_data['value']
    elsif rr_data['role']
      result = Chef::Search::Query.new.search(
        :node,
        "chef_environment:#{@env} AND " \
        "roles:#{rr_data['role']}"
      ).first.first

      fail "No nodes found with role #{rr_data['role']}" if result.nil?

      result.name
    else
      fail "No recognized static record data: #{rr_data.inspect}"
    end
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

  def static_record_nodenames(static_records = {})
    # The purpose of this clunky function is to provide, essentially, DNS
    # overrides.
    #
    # This method builds a hash (compatible with the parser we use in the
    # zone template) containing the RR and value for nodes (or whatever)
    # specified using the static_records attribute.

    if @stub
      fail "#{@apex} requires static_records in order to be a stub" if
        static_records.empty?
      r = node_by_search_data(static_records)
      return {
        @apex => {
          'val' => (IPAddress.valid?(r) ? r : server_ip_by_hostname(r)),
          'type' => 'A'
        }
      }
    end
    static_records.each_with_object({}) do |(rr, rr_data), m|
      Chef::Log.debug('Processing static record: ' \
        "#{rr_data.class}/#{rr}/#{rr_data.inspect}")
      if rr_data.class == String
        m[rr] = { 'val' => rr_data }
      else
        m[rr] = { 'val' => node_by_search_data(rr_data) }
      end
      m[rr]['type'] = rr_data['type'] || 'CNAME'
    end
  end

  def server_ip_by_hostname(hostname)
    server = connection.servers.all(
      'tag-key' => 'Name',
      'tag-value' => hostname
    ).first

    fail "Can't locate server with name #{hostname}" if server.nil?

    server_obj_ip(server)
  end

  def non_public_interfaces(server)
    server.network_interfaces.reject do |ni|
      @avoid_subnets.include?(ni['subnetId']) || ni == {}
    end
  end

  def ec2_network_interfaces
    @ec2_network_interfaces ||= connection.network_interfaces
  end

  def server_obj_ip(server)
    return nil unless server.tags['Name']
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
    nil
  end
end
