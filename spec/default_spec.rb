require 'spec_helper'
require 'byebug'

describe 'et_ec2dnsserver::default' do
  let(:chef_run) do
    # This witchcraft allows us to use the include_recipe resource more than
    # once in a single recipe.
    included_recipes = []
    Chef::RunContext.any_instance.stub(:loaded_recipe?).and_return(false)
    Chef::Recipe.any_instance.stub(:include_recipe) do |i|
      Chef::RunContext.any_instance.stub(:loaded_recipe?).with(i).and_return(true)
      included_recipes << i
    end
    Chef::RunContext.any_instance.stub(:loaded_recipes).and_return(included_recipes)

    ChefSpec::Runner.new do |node|
      node.set['platform_family'] = 'debian'
    end.converge('et_ec2dnsserver::default')
  end
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
    included_recipes = []
    Chef::RunContext.any_instance.stub(:loaded_recipe?).and_return(false)
    Chef::Recipe.any_instance.stub(:include_recipe) do |i|
      Chef::RunContext.any_instance.stub(:loaded_recipe?).with(i).and_return(true)
      included_recipes << i
    end
    Chef::RunContext.any_instance.stub(:loaded_recipes).and_return(included_recipes)

    ChefSpec::Runner.new do |node|
      node.set['platform_family'] = 'debian'
    end.converge('et_ec2dnsserver::default')
  end

  let(:public_ip) { '10.99.1.1' }

  # Set our constants
  let(:vpc_cidr_block) { '10.99.0.0/16' }

  # Fog.mock!
  # Fog::Mock.reset
  let(:fog_conn) do
    conn = Fog::Compute.new(
      provider: 'AWS',
      aws_access_key_id: 'MOCK_ACCESS_KEY',
      aws_secret_access_key: 'MOCK_SECRET_KEY'
    )

    # Create a mock VPC and grab its ID
    conn.create_vpc vpc_cidr_block
    conn
  end

  let(:vpc) { fog_conn.vpcs.find { |v| v.cidr_block == vpc_cidr_block } }

  # Create a subnet in our mock VPC (this will be our public subnet)
  let(:public_subnet_id) do
    fog_conn.create_subnet(
      vpc.id,
      '10.99.1.0/24'
    ).data[:body]['subnet']['subnetId']
  end

  # Create a subnet in our mock VPC (this will be our private subnet)
  let(:private_subnet_id) do
    fog_conn.create_subnet(
      vpc.id,
      private_subnet_cidr_block
    ).data[:body]['subnet']['subnetId']
  end

  before(:each) do
    allow(Chef::EncryptedDataBagItem).to receive(:load).with('secrets', 'aws_credentials').and_return(
      'Ec2DnsServer' => {
        'access_key_id' => 'SAMPLE_ACCESS_KEY_ID',
        'secret_access_key' => 'SECRET_ACCESS_KEY'
      }
    )
    allow(helpers).to receive(:ec2_servers).and_return(fog_conn.servers)
    allow(helpers).to receive(:ec2_network_interfaces).and_return(fog_conn.network_interfaces)
  end

  describe '#get_names_with_ips' do
    context 'host with only public IPs' do
      before(:each) do
        public_server = fog_conn.servers.create
        public_server.wait_for { ready? }
        fog_conn.create_tags(public_server.id, 'Name' => 'node-public')
        public_interface_id = fog_conn.create_network_interface(
          public_subnet_id,
          'PrivateIpAddress' => public_ip
        ).data[:body]['networkInterface']['networkInterfaceId']
        fog_conn.attach_network_interface(
          public_interface_id,
          public_server.id,
          '1'
        )
      end
      # A public IP is expected here because, lacking any private IPs to list,
      # the server_obj_ip falls back to server.private_ip_address which ends up
      # being the public IP because Fog mocking is not that smart.
      it 'return a hash with one public IP record' do
        expect(
          helpers.get_names_with_ips(
            'zone.apex',
            false,
            'vpc-id' => vpc.id,
            'avoid_subnets' => [public_subnet_id]
          )
        ).to eq(
          'node-public' => {
            'type' => 'A',
            'val' => public_ip
          }
        )
      end
    end
  end
end
