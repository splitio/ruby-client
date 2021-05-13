# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class InitProducer
      extend Forwardable
      def_delegators :@init, :record_config, :record_non_ready_usages, :record_bur_timeout

      def initialize(config)
        @init = case config.telemetry_adapter.class.to_s
                when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                  SplitIoClient::Telemetry::RedisInitProducer.new(config)
                else
                  SplitIoClient::Telemetry::MemoryInitProducer.new(config)
                end
      end
    end
  end
end
