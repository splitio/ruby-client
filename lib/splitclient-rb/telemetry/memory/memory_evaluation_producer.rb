# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryEvaluationProducer < EvaluationProducer
      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def record_latency(method, bucket)
        method_latencies = find_method_latencies(method)

        if method_latencies.nil?
          latencies_array = []
          latencies_array << bucket
          @storage.latencies << { method: method, latencies: latencies_array }
        else
          method_latencies[:latencies] << bucket
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_exception(method)
        method_exceptions = find_method_exceptions(method)

        if method_exceptions.nil?
          @storage.exceptions << { method: method, exceptions: 1 }
        else
          method_exceptions[:exceptions] += 1
        end
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      private

      def find_method_latencies(method)
        @storage.latencies.find { |l| l[:method] == method }
      end

      def find_method_exceptions(method)
        @storage.exceptions.find { |l| l[:method] == method }
      end
    end
  end
end
