# frozen_string_literal: true

require 'simplecov'
require 'splitclient-rb'
require 'concurrent'
require 'redis_helper'
require 'timecop'
require 'pry'

require 'webmock/rspec'
require 'simplecov-json'
SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
WebMock.disable_net_connect!

ENV['SPLITCLIENT_ENV'] ||= 'test'

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.include RSpec::RedisHelper, redis: true
  config.before(:all) do
    @default_config = SplitIoClient::SplitConfig.new
    @split_logger = @default_config.split_logger
    @split_validator = @default_config.split_validator
  end
end

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }
