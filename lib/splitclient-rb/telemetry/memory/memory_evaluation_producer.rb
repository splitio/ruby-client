# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryEvaluationProducer
      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter
      end

      def record_latency(method, bucket)
        @adapter.latencies.find { |l| l[:method] == method }[:latencies][bucket] += 1
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end

      def record_exception(method)
        @adapter.exceptions.find { |l| l[:method] == method }[:exceptions].increment
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end
    end
  end
end
