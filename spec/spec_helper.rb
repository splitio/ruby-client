require 'concurrent'
require 'simplecov'
require 'redis_helper'
SimpleCov.start

require 'webmock/rspec'
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include RSpec::RedisHelper, redis: true
end

require 'splitclient-rb'

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }
