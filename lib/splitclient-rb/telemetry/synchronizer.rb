# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class Synchronizer
      extend Forwardable
      def_delegators :@synchronizer,
                     :synchronize_config,
                     :synchronize_stats

      def initialize(config,
                     telemtry_consumers,
                     telemetry_init_producer,
                     repositories,
                     telemetry_api)
        @synchronizer = case config.telemetry_adapter.class.to_s
                        when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                          SplitIoClient::Telemetry::RedisSynchronizer.new(config,
                                                                          telemetry_init_producer)
                        else
                          SplitIoClient::Telemetry::MemorySynchronizer.new(config,
                                                                           telemtry_consumers,
                                                                           repositories,
                                                                           telemetry_api)
                        end
      end
    end
  end
end
