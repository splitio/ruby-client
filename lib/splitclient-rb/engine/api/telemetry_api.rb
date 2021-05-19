# frozen_string_literal: true

module SplitIoClient
  module Api
    class TelemetryApi < Client
      def initialize(config, api_key, telemetry_runtime_producer)
        super(config)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
      end

      def record_init
        # TODO: implement
      end

      def record_stats(stats)
        start = Time.now
        response = post_api("#{@config.telemetry_service_url}/metrics/usage", @api_key, stats)

        if response.success?
          @config.split_logger.log_if_debug("Telemetry post success: record stats.")
          
          bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
          @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::TELEMETRY_SYNC, bucket)
          @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::TELEMETRY_SYNC, (Time.now.to_f * 1000.0).to_i)
        else
          @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::TELEMETRY_SYNC, response.status)
          @config.logger.error("Unexpected status code while posting telemetry: #{response.status}.")
        end
      end
    end
  end
end
