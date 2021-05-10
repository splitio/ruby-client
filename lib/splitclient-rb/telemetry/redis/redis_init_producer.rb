# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RedisInitProducer < InitProducer
      def initialize(config, adapter)
        @config = config
        @adapter = adapter
      end

      def record_config(config_data)
        return if config_data.nil?

        data = { m: { i: @config.machine_ip, n: @config.machine_name, s: "#{@config.language}-#{@config.version}" },
                 t: { om: config_data.om, st: config_data.st, af: config_data.af, rf: config_data.rf, t: config_data.t } }

        @adapter.add_to_queue(config_key, data.to_json)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def record_bur_timeout
        # no-op
      end

      def record_non_ready_usages
        # no-op
      end

      private

      def config_key
        "#{@config.redis_namespace}.telemetry.config"
      end
    end
  end
end
