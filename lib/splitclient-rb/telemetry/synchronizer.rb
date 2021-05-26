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
                     splits_repository,
                     segments_repository,
                     telemetry_api)
        @synchronizer = case config.telemetry_adapter.class.to_s
                        when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                          SplitIoClient::Telemetry::RedisSynchronizer.new(telemtry_consumers[:init])
                        else
                          SplitIoClient::Telemetry::MemorySynchronizer.new(config,
                                                                           telemtry_consumers,
                                                                           splits_repository,
                                                                           segments_repository,
                                                                           telemetry_api)
                        end
      end
    end
  end
end
