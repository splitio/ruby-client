# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class EvaluationConsumer
      extend Forwardable
      def_delegators :@evaluation, :pop_latencies, :pop_exceptions

      def initialize(config)
        @evaluation = SplitIoClient::Telemetry::MemoryEvaluationConsumer.new(config)
      end
    end
  end
end
