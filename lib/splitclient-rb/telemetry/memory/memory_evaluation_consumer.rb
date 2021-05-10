# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemoryEvaluationConsumer < EvaluationConsumer
      def initialize(config, adapter)
        @config = config
        @adapter = adapter
      end

      def pop_latencies
        to_return = @adapter.latencies.each_with_object({}) do |exception, memo|
          memo[exception[:method]] = exception[:latencies]
        end

        @adapter.init_latencies

        to_return
      end

      def pop_exceptions
        to_return = @adapter.exceptions.each_with_object({}) do |exception, memo|
          memo[exception[:method]] = exception[:exceptions].value
        end

        @adapter.init_exceptions

        to_return
      end
    end
  end
end
