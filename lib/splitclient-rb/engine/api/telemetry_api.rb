# frozen_string_literal: true

module SplitIoClient
  module Api
    class TelemetryApi < Client
      def initialize(config, api_key, telemetry_runtime_producer)
        super(config)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
      end

      def record_init(config_init)
        post_telemetry("#{@config.telemetry_service_url}/metrics/config", config_init, 'init')
      end

      def record_stats(stats)
        post_telemetry("#{@config.telemetry_service_url}/metrics/usage", stats, 'stats')
      end

      def record_unique_keys(uniques)
        return if uniques[:keys].empty?

        post_telemetry("#{@config.telemetry_service_url}/keys/ss", uniques, 'unique_keys')
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end

      private

      def post_telemetry(url, obj, method)
        start = Time.now
        response = post_api(url, @api_key, obj)

        if response.success?
          @config.split_logger.log_if_debug("Telemetry post succeeded: record #{method}.")
          
          bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
          @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::TELEMETRY_SYNC, bucket)
          @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::TELEMETRY_SYNC, (Time.now.to_f * 1000.0).to_i)
        else
          @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::TELEMETRY_SYNC, response.status)
          @config.logger.error("Unexpected status code while posting telemetry #{method}: #{response.status}.")
        end
      end
    end
  end
end
