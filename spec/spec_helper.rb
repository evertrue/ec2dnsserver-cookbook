require 'chefspec'
require 'chefspec/berkshelf'
require 'fog'
# require 'rspec/mocks'

require_relative '../libraries/ec2_dns_server.rb'

RSpec.configure do |config|
  config.before(:each) do
    Fog.mock!
    Fog::Mock.reset
  end
end
