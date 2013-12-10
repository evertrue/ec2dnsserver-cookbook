# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  config.vm.hostname = "ec2dnsserver-berkshelf"

  case ENV["VAGRANT_DEFAULT_PROVIDER"]
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


  # Every Vagrant virtual environment requires a box to build off of.
    config.vm.box = "precise64"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
    config.vm.box_url = "http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box"

  end

  # Assign this VM to a host-only network IP, allowing you to access it
  # via the IP. Host-only networks can talk to the host machine as well as
  # any other machines on the same network, but cannot be accessed (through this
  # network interface) by any external networks.
  config.vm.network :private_network, ip: "33.33.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.

  # config.vm.network :public_network

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider :virtualbox do |vb|
  #   # Don't boot with headless mode
  #   vb.gui = true
  #
  #   # Use VBoxManage to customize the VM. For example to change memory:
  #   vb.customize ["modifyvm", :id, "--memory", "1024"]
  # end
  #
  # View the documentation for the provider you're using for more
  # information on available options.

  config.ssh.max_tries = 40
  config.ssh.timeout   = 120

  # The path to the Berksfile to use with Vagrant Berkshelf
  # config.berkshelf.berksfile_path = "./Berksfile"

  # Enabling the Berkshelf plugin. To enable this globally, add this configuration
  # option to your ~/.vagrant.d/Vagrantfile file
  config.berkshelf.enabled = true

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to exclusively install and copy to Vagrant's shelf.
  # config.berkshelf.only = []

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to skip installing and copying to Vagrant's shelf.
  # config.berkshelf.except = []

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
        "recipe[ec2dnsserver::default]"
    ]
  end
end
