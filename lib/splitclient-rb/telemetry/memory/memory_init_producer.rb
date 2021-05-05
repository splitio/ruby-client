# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryInitProducer < InitProducer
      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def record_config
        # no op
      end

      def record_bur_timeout
        counts = find_factory_counters(Domain::Constants::BUR_TIMEOUT)

        if counts.nil?
          @storage.factory_counters << { action: Domain::Constants::BUR_TIMEOUT, counts: 1 }
        else
          counts[:counts] += 1
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_non_ready_usages
        counts = find_factory_counters(Domain::Constants::NON_READY_USAGES)

        if counts.nil?
          @storage.factory_counters << { action: Domain::Constants::NON_READY_USAGES, counts: 1 }
        else
          counts[:counts] += 1
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      private

      def find_factory_counters(action)
        @storage.factory_counters.find { |l| l[:action] == action }
      end
    end
  end
end
