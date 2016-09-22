require 'pry'
require 'concurrent'
require 'simplecov'
SimpleCov.start

require 'webmock/rspec'
WebMock.disable_net_connect!

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

require 'splitclient-rb'
