# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryInitConsumer < InitConsumer
      DEFAULT_VALUE = 0

      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def non_ready_usages
        find_counts(Domain::Constants::NON_READY_USAGES)
      end

      def bur_timeouts
        find_counts(Domain::Constants::BUR_TIMEOUT)
      end

      private

      def find_counts(action)
        @storage.factory_counters.find { |l| l[:action] == action }[:counts].value
      end
    end
  end
end
