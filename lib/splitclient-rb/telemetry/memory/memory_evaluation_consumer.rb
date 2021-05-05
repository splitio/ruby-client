# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryEvaluationConsumer < EvaluationConsumer
      def initialize(config, storage)
        @config = config
        @storage = storage
      end

      def pop_latencies
        to_return = @storage.latencies.each_with_object({}) do |exception, memo|
          memo[exception[:method]] = exception[:latencies]
        end

        @storage.clear_latencies

        to_return
      end

      def pop_exceptions
        to_return = @storage.exceptions.each_with_object({}) do |exception, memo|
          memo[exception[:method]] = exception[:exceptions]
        end

        @storage.clear_exceptions

        to_return
      end
    end
  end
end
