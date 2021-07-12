# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RedisEvaluationProducer < EvaluationProducer
      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter

        @sdk_version = "#{@config.language}-#{@config.version}"
        @name = @config.machine_name
        @ip = @config.machine_ip
      end

      def record_latency(method, bucket)
        @adapter.hincrby(latency_key, "#{@sdk_version}/#{@name}/#{@ip}/#{method}/#{bucket}", 1)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_exception(method)
        @adapter.hincrby(exception_key, "#{@sdk_version}/#{@name}/#{@ip}/#{method}", 1)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      private

      def latency_key
        "#{@config.redis_namespace}.telemetry.latencies"
      end

      def exception_key
        "#{@config.redis_namespace}.telemetry.exceptions"
      end
    end
  end
end
