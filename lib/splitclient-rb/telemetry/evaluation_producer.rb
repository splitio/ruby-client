# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class EvaluationProducer
      extend Forwardable
      def_delegators :@evaluation,
                     :record_latency,
                     :record_exception

      def initialize(config)
        @evaluation = case config.telemetry_adapter.class.to_s
                      when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                        SplitIoClient::Telemetry::RedisEvaluationProducer.new(config)
                      else
                        SplitIoClient::Telemetry::MemoryEvaluationProducer.new(config)
                      end
      end
    end
  end
end
