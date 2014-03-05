class Chef::Recipe::Ec2DnsServer
  require 'ipaddress'

  def self.valid_hostname?(hostname)
    return false if hostname.length > 255 || hostname.scan('..').any?

    hostname = hostname[0 ... -1] if hostname.index('.', -1)

    hostname.split('.').map do |i|
      i.size <= 63 && !(
          i.rindex('-', 0) ||
          i.index('-', -1) ||
          i.scan(/[^a-z\d-]/i).any?
        )
    end.all?
  end

  def node_by_search_data(rr_data)
    if rr_data['cookbook']
      result = Chef::Search::Query.new.search(
          :node,
          "chef_environment:#{@env} AND " +
          "recipes:#{rr_data['cookbook']}"
        ).first.first

      fail "No nodes found with cookbook #{rr_data['cookbook']}" if result.nil?

      rr = result.name
    elsif rr_data['value']
      rr = rr_data['value']
    elsif rr_data['role']
      result = Chef::Search::Query.new.search(
          :node,
          "chef_environment:#{@env} AND " +
          "roles:#{rr_data['role']}"
        ).first.first

      fail "No nodes found with role #{rr_data['role']}" if result.nil?

      rr = result.name
    else
      fail "No recognized static record data: #{rr_data.inspect}"
    end

    rr
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
    connection.network_interfaces.all(filter).first
  end

  def static_record_nodenames(static_records = {})
    # The purpose of this clunky function is to provide, essentially, DNS
    # overrides.
    #
    # This method builds a hash (compatible with the parser we use in the
    # zone template) containing the RR and value for nodes (or whatever)
    # specified using the static_records attribute.

    h = {}

    if @stub
      fail "#{@apex} requires static_records in order to be a stub" if static_records.empty?
      r = node_by_search_data(static_records)
      h[@apex] = {
        'val' => IPAddress.valid?(r) ? r : server_ip_by_hostname(r)
      }
      h[@apex]['type'] = 'A'
    else
      static_records.each do |rr, rr_data|
        Chef::Log.debug("Processing static record: " \
          "#{rr_data.class}/#{rr}/#{rr_data.inspect}")
        if rr_data.class == String
          h[rr] = { 'val' => rr_data }
        else
          h[rr] = { 'val' => node_by_search_data(rr_data) }
        end
        h[rr]['type'] = 'CNAME'
      end
    end

    h
  end

  def server_ip_by_hostname(hostname)
    server = connection.servers.all(
      'tag-key' => 'Name',
      'tag-value' => hostname
    ).first

    fail "Can't locate server with name #{hostname}" if server.nil?

    server_obj_ip(server)
  end

  def server_obj_ip(server)
    server.network_interfaces.reject { |ni|
      @avoid_subnets.include?ni['subnetId']
    }.reject { |ni|
      ni == {}
    }.map { |ni|
      # Don't avoid an IP if it's the only IP.
      ec2_network_interfaces(
        'network-interface-id' => ni['networkInterfaceId']
      ).private_ip_address
    }.first || server.private_ip_address
  end

  def get_names_with_ips(apex, stub, options = {})
    @apex = apex
    @stub = stub
    filter = {}
    filter['vpc-id'] = options['vpc-id'] if options['vpc-id']
    @avoid_subnets = options['avoid_subnets'] || []

    Chef::Log.info('Avoiding these subnets: ' +
      options['avoid_subnets'].join(',')) unless @avoid_subnets == []

    h = {}
    unless @stub
      ec2_servers(filter).map do |s|
        if s.tags['Name']
          h[s.tags['Name']] = {
            'type' => 'A',
            'val' => server_obj_ip(s)
          }
        end
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

  def initialize(node, env)
    @node = node
    @env = env
  end
end
