require 'spec_helper'

describe 'et_ec2dnsserver::default' do
  let(:chef_run) do
    ChefSpec::Runner.new do |node|
      node.set['platform_family'] = 'debian'
    end.converge('et_ec2dnsserver::default')
  end
end

describe Chef::Recipe::Ec2DnsServer do
  describe '#self.forwarders' do
    context 'statically defined forwarders' do
      it 'return the contents of the forwarders key' do
        expect(
          Chef::Recipe::Ec2DnsServer.forwarders(
            'ec2dnsserver' => {
              'forwarders' => 'foo'
            }
          )
        ).to eq('foo')
      end
    end

    context 'no static-forwarders but VPC is set' do
      it 'return a VPC-derived value' do
        expect(
          Chef::Recipe::Ec2DnsServer.forwarders(
            'ec2dnsserver' => {},
            'ec2' => {
              'mac' => '00:00:00:aa:bb:cc',
              'network_interfaces_macs' => {
                '00:00:00:aa:bb:cc' => {
                  'vpc_ipv4_cidr_block' => '10.1.0.0/16'
                }
              }
            }
          )
        ).to eq(['10.1.0.2'])
      end
    end

    context 'neither static-forwarders nor VPC' do
      it 'return a hard-coded value' do
        expect(
          Chef::Recipe::Ec2DnsServer.forwarders(
            'ec2dnsserver' => {},
            'ec2' => {
              'mac' => '00:00:00:aa:bb:cc',
              'network_interfaces_macs' => {
                '00:00:00:aa:bb:cc' => {}
              }
            }
          )
        ).to eq(['10.0.0.2'])
      end
    end
  end

  describe '#self.valid_hostname?' do
    context 'hostname is valid' do
      it 'true' do
        expect(Chef::Recipe::Ec2DnsServer.valid_hostname?('foobar'))
          .to eq(true)
      end
    end

    context 'hostname is not valid' do
      it 'false' do
        expect(Chef::Recipe::Ec2DnsServer.valid_hostname?('-foo_ba r-'))
          .to eq(false)
      end
    end
  end

  describe '#vpc_default_dns' do
    it 'return the second valid IP address in the subnet' do
      expect(Chef::Recipe::Ec2DnsServer.vpc_default_dns('10.1.0.0/16'))
        .to eq('10.1.0.2')
    end
  end

  # Set our constants
  let(:test_zone_apex) { 'test.apex' }
  let(:vpc_cidr_block) { '10.99.0.0/16' }
  let(:public_subnet) { '10.99.23.0/24' }
  let(:private_subnet) { '10.99.1.0/24' }
  let(:public_ip) { IPAddress::IPv4.new(public_subnet).first.address }
  let(:private_ip) { IPAddress::IPv4.new(private_subnet).first.address }
  let(:private_ip_2) { IPAddress::IPv4.new(private_subnet).map(&:address)[2] }

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
      public_subnet
    ).data[:body]['subnet']['subnetId']
  end

  # Create a subnet in our mock VPC (this will be our private subnet)
  let(:private_subnet_id) do
    fog_conn.create_subnet(
      vpc.id,
      private_subnet
    ).data[:body]['subnet']['subnetId']
  end

  describe '#names_with_ips' do
    context 'full stack test' do
      let(:helpers) do
        Chef::Recipe::Ec2DnsServer.new(
          'stage',
          test_zone_apex,
          'avoid_subnets' => [public_subnet_id]
        )
      end

      let(:server) do
        server = fog_conn.servers.create
        server.wait_for { ready? }
        server
      end

      before(:each) do
        allow(helpers).to receive(:ec2_servers).and_return(fog_conn.servers)
      end

      context 'host with one private ("non-avoid") IP' do
        before(:each) do
          fog_conn.create_tags(server.id, 'Name' => 'node-one-private')
          private_interface_id = fog_conn.create_network_interface(
            private_subnet_id,
            'PrivateIpAddress' => private_ip
          ).data[:body]['networkInterface']['networkInterfaceId']
          fog_conn.attach_network_interface(
            private_interface_id,
            server.id,
            '1'
          )
          allow(helpers).to receive(:ec2_network_interfaces)
            .and_return(fog_conn.network_interfaces)
        end

        # Ensures that public interfaces are properly ignored
        it 'return a hash with one private IP record' do
          expect(
            helpers.send(:names_with_ips, 'vpc-id' => vpc.id)
          ).to eq(
            'node-one-private' => {
              'type' => 'A',
              'val' => private_ip
            }
          )
        end
      end

      context 'host with only public ("avoid") IPs' do
        before(:each) do
          fog_conn.create_tags(server.id, 'Name' => 'node-public')
          public_interface_id = fog_conn.create_network_interface(
            public_subnet_id,
            'PrivateIpAddress' => public_ip
          ).data[:body]['networkInterface']['networkInterfaceId']
          fog_conn.attach_network_interface(
            public_interface_id,
            server.id,
            '1'
          )
        end
        # A public IP is expected here because, lacking any non-excluded IPs to list,
        # the server_obj_ip falls back to server.private_ip_address which ends up
        # being the public IP because Fog mocking doesn't understand that
        # 'avoid_subnets' refers to public interfaces.
        it 'return a hash with one public IP record' do
          expect(helpers.send(:names_with_ips, 'vpc-id' => vpc.id)).to eq(
            'node-public' => {
              'type' => 'A',
              'val' => public_ip
            }
          )
        end
      end

      context 'host with both public ("avoid") and private ("non-avoid") IPs' do
        before(:each) do
          fog_conn.create_tags(server.id, 'Name' => 'node-both')
          public_interface_id = fog_conn.create_network_interface(
            public_subnet_id,
            'PrivateIpAddress' => public_ip
          ).data[:body]['networkInterface']['networkInterfaceId']
          fog_conn.attach_network_interface(
            public_interface_id,
            server.id,
            '1'
          )
          private_interface_id = fog_conn.create_network_interface(
            private_subnet_id,
            'PrivateIpAddress' => private_ip
          ).data[:body]['networkInterface']['networkInterfaceId']
          fog_conn.attach_network_interface(
            private_interface_id,
            server.id,
            '2'
          )
          allow(helpers).to receive(:ec2_network_interfaces)
            .and_return(fog_conn.network_interfaces)
        end

        # Ensures that public interfaces are properly ignored
        it 'return a hash with one private IP record' do
          expect(helpers.send(:names_with_ips, 'vpc-id' => vpc.id)).to eq(
            'node-both' => {
              'type' => 'A',
              'val' => private_ip
            }
          )
        end
      end

      context 'host with two private ("non-avoid") IPs' do
        before(:each) do
          fog_conn.create_tags(server.id, 'Name' => 'node-both')
          private_interface_id = fog_conn.create_network_interface(
            private_subnet_id,
            'PrivateIpAddress' => private_ip
          ).data[:body]['networkInterface']['networkInterfaceId']
          fog_conn.attach_network_interface(
            private_interface_id,
            server.id,
            '1'
          )
          private_interface_2_id = fog_conn.create_network_interface(
            private_subnet_id,
            'PrivateIpAddress' => private_ip_2
          ).data[:body]['networkInterface']['networkInterfaceId']
          fog_conn.attach_network_interface(
            private_interface_2_id,
            server.id,
            '2'
          )
          allow(helpers).to receive(:ec2_network_interfaces)
            .and_return(fog_conn.network_interfaces)
        end

        # Ensures that public interfaces are properly ignored
        it 'return a hash with one private IP record' do
          expect(helpers.send(:names_with_ips, 'vpc-id' => vpc.id)).to eq(
            'node-both' => {
              'type' => 'A',
              'val' => private_ip
            }
          )
        end
      end
    end

    context 'no static records' do
      let(:helpers) { Chef::Recipe::Ec2DnsServer.new('stage', test_zone_apex) }
      let(:server) do
        server = fog_conn.servers.create
        server.wait_for { ready? }
        server
      end

      before(:each) do
        allow(helpers).to receive(:ec2_servers).and_return(fog_conn.servers)
        allow(helpers).to receive(:static_record_nodenames).and_return({})
      end

      context 'server with no name tag' do
        it 'return an empty hash' do
          expect(helpers.send(:names_with_ips)).to eq({})
        end
      end

      context 'server with invalid name tag' do
        it 'return an empty hash' do
          fog_conn.create_tags(server.id, 'Name' => '-invalid_nam e-')
          expect(helpers.send(:names_with_ips)).to eq({})
        end
      end

      context 'server with name tag' do
        before(:each) do
          fog_conn.create_tags(server.id, 'Name' => 'test-node')
        end

        context 'and private IP' do
          it 'return a hash with the name and IP' do
            allow(helpers).to receive(:server_obj_ip)
              .with(any_args).and_return('10.0.0.1')
            expect(helpers.send(:names_with_ips)).to eq(
              'test-node' => {
                'type' => 'A',
                'val' => '10.0.0.1'
              }
            )
          end
        end

        context 'and no private IP' do
          it 'return an empty hash' do
            allow(helpers).to receive(:server_obj_ip)
              .with(any_args).and_return(false)
            expect(helpers.send(:names_with_ips)).to eq({})
          end
        end
      end
    end

    context 'with static records' do
      let(:helpers) { Chef::Recipe::Ec2DnsServer.new('stage', test_zone_apex) }
      let(:server) do
        server = fog_conn.servers.create
        server.wait_for { ready? }
        server
      end

      before(:each) do
        allow(helpers).to receive(:override_records).with(any_args).and_return(
          'static-record-node' => {
            'val' => 'some-hostname',
            'type' => 'CNAME'
          }
        )
        allow(helpers).to receive(:ec2_servers).and_return(fog_conn.servers)
      end

      context 'with name tag' do
        before(:each) do
          fog_conn.create_tags(server.id, 'Name' => 'test-node')
        end

        context 'with private IP' do
          before(:each) do
            allow(helpers).to receive(:server_obj_ip)
              .with(any_args).and_return('10.0.0.1')
          end

          it 'returns a merged hash of the host and the static record' do
            expect(helpers.send(:names_with_ips)).to eq(
              'test-node' => {
                'type' => 'A',
                'val' => '10.0.0.1'
              },
              'static-record-node' => {
                'val' => 'some-hostname',
                'type' => 'CNAME'
              }
            )
          end
        end
      end
    end
  end

  describe '#node_by_search_data' do
    let(:helpers) { Chef::Recipe::Ec2DnsServer.new('stage', test_zone_apex) }

    context 'search data: cookbook' do
      context 'searched cookbook exists' do
        it 'perform a Chef search and return the node name' do
          chef_node = object_double('chef_node', name: 'chef-node-name')
          allow_any_instance_of(Chef::Search::Query).to receive(:search)
            .with(
              :node,
              'chef_environment:stage AND ' \
              'run_list:recipe\\[some-cookbook\\]'
            ).and_return([[chef_node]])
          expect(
            helpers.instance_eval do
              node_by_search_data(
                'cookbook' => 'some-cookbook'
              )
            end
          ).to eq(chef_node)
        end
      end

      context 'searched cookbook does not exist' do
        it 'raise an error' do
          allow_any_instance_of(Chef::Search::Query).to receive(:search)
            .with(any_args).and_return([[]])
          expect do
            helpers.send(
              :node_by_search_data,
              'cookbook' => 'some-cookbook'
            )
          end.to raise_error(
            RuntimeError,
            'No nodes found with cookbook some-cookbook'
          )
        end
      end
    end

    context 'search data: role' do
      context 'searched role exists' do
        it 'perform a Chef search and return the node name' do
          chef_node = object_double('chef_node', name: 'chef-node-name')
          allow_any_instance_of(Chef::Search::Query).to receive(:search)
            .with(
              :node,
              'chef_environment:stage AND ' \
              'roles:some-role'
            ).and_return([[chef_node]])
          expect(
            helpers.instance_eval do
              node_by_search_data(
                'role' => 'some-role'
              )
            end
          ).to eq(chef_node)
        end
      end

      context 'searched role does not exist' do
        it 'raise an error' do
          allow_any_instance_of(Chef::Search::Query).to receive(:search)
            .with(any_args).and_return([[]])
          expect do
            helpers.send(
              :node_by_search_data,
              'role' => 'some-role'
            )
          end.to raise_error(
            RuntimeError,
            'No nodes found with role some-role'
          )
        end
      end
    end

    context 'search data: invalid' do
      it 'raise an error' do
        expect { helpers.send(:node_by_search_data, 'invalid' => 'data') }
          .to raise_error(
            RuntimeError,
            'No recognized static record data: {"invalid"=>"data"}'
          )
      end
    end
  end

  describe '#override_records' do
    context 'no static records' do
      let(:helpers) { Chef::Recipe::Ec2DnsServer.new('stage', test_zone_apex) }
      it 'return {}' do
        expect(helpers.send(:override_records, {})).to eq({})
      end
    end
  end

  describe '#override_record' do
    let(:helpers) { Chef::Recipe::Ec2DnsServer.new('stage', test_zone_apex) }

    context 'hash value with "value"' do
      context 'with type field' do
        it 'return a hash of the input values' do
          expect(
            helpers.send(:override_record, 'value' => 'some-value', 'type' => 'A')
          ).to eq('val' => 'some-value', 'type' => 'A')
        end
      end

      context 'without type field' do
        it 'raise an error' do
          expect { helpers.send(:override_record, 'value' => 'some-value') }
            .to raise_error(
              RuntimeError,
              'No record type specified for some-value'
            )
        end
      end
    end

    context 'hash value with cookbook' do
      let(:chef_node) do
        Hashie::Mash.new name: 'some-node', ipaddress: '1.2.3.4'
      end

      it 'call node_by_search_data' do
        expect(helpers).to receive(:node_by_search_data).with(
          'cookbook' => 'test_cookbook'
        ).and_return(chef_node)
        helpers.send(:override_record, 'cookbook' => 'test_cookbook')
      end

      it 'return a value/type rr hash' do
        allow(helpers).to receive(:node_by_search_data).with(any_args)
          .and_return(chef_node)
        expect(
          helpers.send(:override_record, 'cookbook' => 'test_cookbook')
        ).to eq('val' => '1.2.3.4', 'type' => 'A')
      end
    end
  end
end
