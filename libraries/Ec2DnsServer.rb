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

  def chef_nodename(static_records, env)

    # The purpose of this clunky function is to provide, essentially, DNS
    # overrides.
    #
    # This method builds a hash (compatible with the parser we use in the
    # zone template) containing the RR and value for nodes (or whatever)
    # specified using the static_records attribute.

    h = {}

    static_records.each do |rr,rr_data|
      begin
        Chef::Log.debug("Processing static record: #{rr_data.class}/#{rr}/#{rr_data.inspect}")
        if rr_data.class == String
          h[rr] = {'val' => rr_data}
        elsif rr_data['cookbook']
          result = Chef::Search::Query.new.search(
              :node,
              "chef_environment:#{env} AND " +
              "recipes:#{rr_data['cookbook']}"
            ).first.first

          if result.nil?
            raise "No nodes found with cookbook #{rr_data['cookbook']}"
          end

          h[rr] = { 'val' => result.name }
        elsif rr_data['role']
          result = Chef::Search::Query.new.search(
              :node,
              "chef_environment:#{env} AND " +
              "roles:#{rr_data['role']}"
            ).first.first

          if result.nil?
            raise "No nodes found with role #{rr_data['role']}"
          end

          h[rr] = { 'val' => result.name }
        else
          raise "No recognized static record data: #{rr_data.inspect}"
        end
        h[rr]['type'] = 'CNAME'
      end
    end

    return h

  end

  def get_names_with_ips(vpc = nil, avoid_subnets = [], static_records, env)

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
        h[s.tags["Name"]] = {
          'type' => 'A',
          'val' => s.network_interfaces.reject { |ni|
              avoid_subnets.include?ni["subnetId"]
            }.reject { |ni|
              ni == {}
            }.map { |ni|
              # Don't avoid an IP if it's the only IP.
              conn.network_interfaces.get(ni["networkInterfaceId"]).private_ip_address
            }.first || s.private_ip_address
        }
      end
    end

    h.merge!(chef_nodename(static_records, env))

    return h

  end

  def initialize(node)
    @node = node
  end

end
