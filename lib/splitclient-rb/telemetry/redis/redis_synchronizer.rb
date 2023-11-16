# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RedisSynchronizer
      def initialize(config,
                     telemetry_init_producer)
        @config = config
        @telemetry_init_producer = telemetry_init_producer
      end

      def synchronize_stats
        # No-op
      end

      def synchronize_config(active_factories = nil, redundant_active_factories = nil, tags = nil)
        active_factories ||= SplitIoClient.split_factory_registry.active_factories
        redundant_active_factories ||= SplitIoClient.split_factory_registry.redundant_active_factories

        init_config = ConfigInit.new(@config.mode, 'redis', active_factories, redundant_active_factories, tags)

        @telemetry_init_producer.record_config(init_config)
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end
    end
  end
end
