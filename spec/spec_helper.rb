# frozen_string_literal: true

require 'simplecov'
require 'splitclient-rb'
require 'concurrent'
require 'redis_helper'
require 'timecop'
require 'pry'

require 'webmock/rspec'
WebMock.disable_net_connect!

ENV['SPLITCLIENT_ENV'] ||= 'test'

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include RSpec::RedisHelper, redis: true
  config.before(:all) do
    SplitIoClient.configuration = nil
    SplitIoClient.configure
  end
end

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }
