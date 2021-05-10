# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryInitProducer < InitProducer
      def initialize(config, adapter)
        @config = config
        @adapter = adapter
      end

      def record_config
        # no op
      end

      def record_bur_timeout
        find_factory_counters(Domain::Constants::BUR_TIMEOUT)[:counts].increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_non_ready_usages
        find_factory_counters(Domain::Constants::NON_READY_USAGES)[:counts].increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      private

      def find_factory_counters(action)
        @adapter.factory_counters.find { |l| l[:action] == action }
      end
    end
  end
end
