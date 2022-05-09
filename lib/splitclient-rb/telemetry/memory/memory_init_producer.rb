# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryInitProducer
      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter
      end

      def record_config
        # no op
      end

      def record_bur_timeout
        find_factory_counters(Domain::Constants::BUR_TIMEOUT)[:counts].increment
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end

      def record_non_ready_usages
        find_factory_counters(Domain::Constants::NON_READY_USAGES)[:counts].increment
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end

      private

      def find_factory_counters(action)
        @adapter.factory_counters.find { |l| l[:action] == action }
      end
    end
  end
end
