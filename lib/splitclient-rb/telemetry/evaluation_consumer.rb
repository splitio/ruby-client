# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class EvaluationConsumer
      extend Forwardable
      def_delegators :@evaluation, :pop_latencies, :pop_exceptions

      def initialize(config, storage)
        @evaluation = SplitIoClient::Telemetry::MemoryEvaluationConsumer.new(config, storage)
      end
    end
  end
end
