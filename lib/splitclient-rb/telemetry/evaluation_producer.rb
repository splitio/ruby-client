# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class EvaluationProducer
      extend Forwardable
      def_delegators :@evaluation, :record_latency, :record_exception

      def initialize(config, storage)
        @evaluation = SplitIoClient::Telemetry::MemoryEvaluationProducer.new(config, storage)
      end
    end
  end
end
