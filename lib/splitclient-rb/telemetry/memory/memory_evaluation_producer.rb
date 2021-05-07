# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryEvaluationProducer < EvaluationProducer
      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def record_latency(method, bucket)
        @storage.latencies.find { |l| l[:method] == method }[:latencies] << bucket
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_exception(method)
        @storage.exceptions.find { |l| l[:method] == method }[:exceptions].increment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end
    end
  end
end
