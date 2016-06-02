require 'chefspec'
require 'chefspec/berkshelf'
require 'hashie'
require 'fog'
require 'ipaddress'
# require 'rspec/mocks'

require_relative '../libraries/ec2_dns_server.rb'

RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
  config.before(:each) do
    Fog.mock!
    Fog::Mock.reset
    Fog::Mock.delay = 0
  end
end
