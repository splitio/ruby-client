# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class InitProducer
      extend Forwardable
      def_delegators :@init, :record_config, :record_non_ready_usages, :record_bur_timeout

      def initialize(config, adapter)
        @init = case adapter.class.to_s
                when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                  SplitIoClient::Telemetry::RedisInitProducer.new(config, adapter)
                else
                  SplitIoClient::Telemetry::MemoryInitProducer.new(config, adapter)
                end
      end
    end
  end
end
