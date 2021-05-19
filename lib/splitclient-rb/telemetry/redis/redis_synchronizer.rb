# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RedisSynchronizer < Synchronizer
      def initialize(telemetry_init_consumer)
        @telemetry_init_consumer = telemetry_init_consumer
      end

      def synchronize_stats
        # No-op
      end

      def synchronize_config(init_config, timed_until_ready, factory_instances, tags)
        # implement
      end
    end
  end
end
