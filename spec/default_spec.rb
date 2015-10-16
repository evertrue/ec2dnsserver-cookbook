require 'spec_helper'

describe 'et_ec2dnsserver::default' do
  let(:chef_run) do
    # This witchcraft allows us to use the include_recipe resource more than
    # once in a single recipe.
    @included_recipes = []
    Chef::RunContext.any_instance.stub(:loaded_recipe?).and_return(false)
    Chef::Recipe.any_instance.stub(:include_recipe) do |i|
      Chef::RunContext.any_instance.stub(:loaded_recipe?).with(i).and_return(true)
      @included_recipes << i
    end
    Chef::RunContext.any_instance.stub(:loaded_recipes).and_return(@included_recipes)

    ChefSpec::Runner.new do |node|
      node.set['platform_family'] = 'debian'
    end.converge('et_ec2dnsserver::default')
  end
  # before do
  #   Fog.mock!
  #   @trusted_networks_obj = {
  #     'id' => 'trusted_networks',
  #     'global' => [
  #       '127.0.0.1/24',
  #       {
  #         'name' => 'Fake Name',
  #         'contact' => 'fake@contact.com',
  #         'network' => '192.168.19.0/24'
  #       }
  #     ]
  #   }
  #   Chef::EncryptedDataBagItem.stub(:load).with('secrets','aws_credentials').and_return(
  #     {
  #       'Ec2Haproxy' => {
  #         'access_key_id' => 'SAMPLE_ACCESS_KEY_ID',
  #         'secret_access_key' => 'SECRET_ACCESS_KEY'
  #       }
  #     }
  #   )
  #   stub_data_bag('access_control').and_return([
  #     { id: 'trusted_networks' }
  #   ])
  #   stub_data_bag_item('access_control','trusted_networks').and_return(@trusted_networks_obj)
  # end
end

describe Chef::Recipe::Ec2DnsServer do
  let(:helpers) do
    Chef::Recipe::Ec2DnsServer.new(
      {
        'ec2dnsserver' => {
          'aws_api_user' => 'Ec2DnsServer'
        }
      },
      'stage'
    )
  end

  let(:chef_run) do
    # This witchcraft allows us to use the include_recipe resource more than
    # once in a single recipe.
    @included_recipes = []
    Chef::RunContext.any_instance.stub(:loaded_recipe?).and_return(false)
    Chef::Recipe.any_instance.stub(:include_recipe) do |i|
      Chef::RunContext.any_instance.stub(:loaded_recipe?).with(i).and_return(true)
      @included_recipes << i
    end
    Chef::RunContext.any_instance.stub(:loaded_recipes).and_return(@included_recipes)

    ChefSpec::Runner.new do |node|
      node.set['platform_family'] = 'debian'
    end.converge('et_ec2dnsserver::default')
  end

  before do
    # Fog.mock!
    # Fog::Mock.reset
    @fog_conn = Fog::Compute.new(
      provider: 'AWS',
      aws_access_key_id: 'MOCK_ACCESS_KEY',
      aws_secret_access_key: 'MOCK_SECRET_KEY'
    )

    # Set our constants
    @vpc_cidr_block = '10.99.0.0/16'

    @private_subnet_cidr_block = '10.99.2.0/24'
    @private_ip_1 = '10.99.2.2'
    @private_ip_2 = '10.99.2.3'

    @public_subnet_cidr_block = '10.99.1.0/24'
    @public_ip = '10.99.1.1'

    # Create a mock VPC and grab its ID
    @fog_conn.create_vpc(@vpc_cidr_block)
    @vpc = @fog_conn.vpcs.find { |v| v.cidr_block == @vpc_cidr_block }
    @vpc_id = @vpc.id

    # Create a subnet in our mock VPC (this will be our public subnet)
    @public_subnet_id = @fog_conn.create_subnet(@vpc_id, @public_subnet_cidr_block).data[:body]['subnet']['subnetId']

    # Create a subnet in our mock VPC (this will be our private subnet)
    @private_subnet_id = @fog_conn.create_subnet(@vpc_id, @private_subnet_cidr_block).data[:body]['subnet']['subnetId']

    # Create a mock public network Interface
    @public_interface_id = @fog_conn.create_network_interface(
      @public_subnet_id,
      'PrivateIpAddress' => @public_ip
    ).data[:body]['networkInterface']['networkInterfaceId']

    # Create some servers
    @public_server = @fog_conn.servers.create(
      'SubnetId' => @private_subnet_id,
      'PrivateIpAddress' => @private_ip_1
    )
    @private_server = @fog_conn.servers.create(
      'SubnetId' => @private_subnet_id,
      'PrivateIpAddress' => @private_ip_2
    )

    @public_server.wait_for { ready? }
    @private_server.wait_for { ready? }

    @fog_conn.create_tags(@public_server.id, 'Name' => 'node-public')
    @fog_conn.create_tags(@private_server.id, 'Name' => 'node-private')

    # Attach our "avoid" public network interface to one of our instances
    @fog_conn.attach_network_interface(@public_interface_id, @public_server.id, '2')

    expect(helpers).to receive(:ec2_servers).and_return(@fog_conn.servers)
    expect(helpers).to receive(:ec2_network_interfaces).and_return(@fog_conn.network_interfaces)

    expect(Chef::EncryptedDataBagItem).to receive(:load).with('secrets', 'aws_credentials').and_return(
      'Ec2DnsServer' => {
        'access_key_id' => 'SAMPLE_ACCESS_KEY_ID',
        'secret_access_key' => 'SECRET_ACCESS_KEY'
      }
    )
  end

  describe 'get_names_with_ips' do
    it 'should return a hash of zone data' do
      expect(
        helpers.get_names_with_ips(
          'zone.apex',
          false,
          'vpc-id' => @vpc_id,
          'avoid_subnets' => [@public_subnet_id]
        )
      ).to eq(
        @public_server.tags['Name'] => {
          'type' => 'A',
          'val' => @private_ip_1
        },
        @private_server.tags['Name'] => {
          'type' => 'A',
          'val' => @private_ip_2
        }
      )
    end
  end
end
