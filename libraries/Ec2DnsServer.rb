class Chef::Recipe::Ec2DnsServer

  def get_names_with_ips(vpc = nil)

    require 'fog'

    aws_keys = Chef::EncryptedDataBagItem.load("secrets","aws_credentials")[@node['ec2dnsserver']['aws_api_user']]

    conn = Fog::Compute.new(
      :provider => "AWS",
      :aws_access_key_id => aws_keys['access_key_id'],
      :aws_secret_access_key => aws_keys['secret_access_key']
    )

    filter = { 'vpc-id' => vpc } if vpc

    h = Hash.new
    conn.servers.all(filter).map do |s| 
      h[s.tags["Name"]] = s.private_ip_address if s.tags["Name"] 
    end

    h

  end

  def initialize(node)
    @node = node
  end

end