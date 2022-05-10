# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryInitConsumer
      DEFAULT_VALUE = 0

      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter
      end

      def non_ready_usages
        find_counts(Domain::Constants::NON_READY_USAGES)
      end

      def bur_timeouts
        find_counts(Domain::Constants::BUR_TIMEOUT)
      end

      private

      def find_counts(action)
        @adapter.factory_counters.find { |l| l[:action] == action }[:counts].value
      end
    end
  end
end
