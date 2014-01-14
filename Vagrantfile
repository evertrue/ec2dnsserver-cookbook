# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  config.vm.hostname = "ec2dnsserver-berkshelf"

  case ENV["VAGRANT_CUSTOM_PROVIDER"]
  when "aws"

    config.vm.box = "dummy"
    config.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"

    config.vm.provider :aws do |aws, override|
      aws.access_key_id = "AKIAIBHMPZ2OF7KX7OVA"
      aws.secret_access_key = File.read("#{ENV['HOME']}/.aws_secret_access_key").chomp
      aws.keypair_name = "jenkins_vagrant"
      aws.private_ip_address = "10.0.4.165"

      aws.ami = "ami-cf5e2ba6"

      aws.security_groups = "sg-5664c239"
      aws.subnet_id = "subnet-2f303240"
      aws.tags = {
        "Name" => "prod-JenkinsVagrant-#{config.vm.hostname}",
        "Role" => "Jenkins Vagrant Testing",
        "Env" => "prod"
      }

      override.ssh.username = "ubuntu"
      override.ssh.private_key_path = "#{ENV['HOME']}/.ssh/jenkins_vagrant.pem"
      override.ssh.host = "10.0.4.165"
    end

  else


    config.vm.box = "precise64"
    config.vm.box_url = "http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box"

  end
  config.vm.network :private_network, ip: "33.33.33.10"

  config.berkshelf.enabled = true

  config.vm.provision :shell, :inline => "curl -s -L https://www.opscode.com/chef/install.sh | sudo bash"
  config.vm.provision :shell, :inline => "sudo mkdir -p /etc/bind && sudo bash -c \"echo 'forwarders { 10.0.0.2; };' > /etc/bind/named.conf.forwarders\""
  config.vm.provision :shell, :inline => "sudo mkdir -p /var/chef && sudo ln -sf /vagrant/.chef-repo/data_bags /var/chef/data_bags"

  if ENV['CHEF_REPO']
    chef_repo = ENV['CHEF_REPO']
  else
    raise "CHEF_REPO is not defined"
  end

  config.vm.provision :chef_solo do |chef|
    chef.json = {
      "ec2dnsserver" => {
        "vpc" => "vpc-ca7dcfa1",
        "zones" => [
          {
            'apex' => 'priv.evertrue.com',
            'ptr_zone' => false,
            'suffix' => 'priv.evertrue.com'
          },
          {
            'apex' => '10.in-addr.arpa',
            'ptr_zone' => true,
            'suffix' => 'priv.evertrue.com'
          }
        ]
      }
    }
    chef.log_level = :debug
    chef.data_bags_path = "#{chef_repo}/data_bags"
    chef.encrypted_data_bag_secret_key_path = "#{ENV['HOME']}/.chef/encrypted_data_bag_secret"

    chef.run_list = [
        "recipe[et_base]",
        "recipe[ec2dnsserver::default]"
    ]
  end
end
