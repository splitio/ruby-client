# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class RedisInitProducer < InitProducer
      EXPIRE_SECONDS = 3600

      def initialize(config)
        @config = config
        @adapter = config.telemetry_adapter
      end

      def record_config(config_data)
        return if config_data.nil?

        data = { t: { oM: config_data.om, st: config_data.st, aF: config_data.af, rF: config_data.rf, t: config_data.t } }
        field = "#{@config.language}-#{@config.version}/#{@config.machine_name}/#{@config.machine_ip}"

        result = @adapter.add_to_map(config_key, field, data.to_json)

        @adapter.expire(config_key, EXPIRE_SECONDS) if result == 1
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
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
