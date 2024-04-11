# frozen_string_literal: true

module SplitIoClient
  module Api
    class Impressions < Client
      def initialize(api_key, config, telemetry_runtime_producer, request_decorator)
        super(config, request_decorator)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
      end

      def post(impressions)
        if impressions.empty?
          @config.split_logger.log_if_debug('No impressions to report')
          return
        end

        start = Time.now

        response = post_api("#{@config.events_uri}/testImpressions/bulk", @api_key, impressions, impressions_headers)

        if response.success?
          @config.split_logger.log_if_debug("Impressions reported: #{total_impressions(impressions)}")

          bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
          @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::IMPRESSIONS_SYNC, bucket)
          @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::IMPRESSIONS_SYNC, (Time.now.to_f * 1000.0).to_i)
        else
          @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::IMPRESSIONS_SYNC, response.status)

          @config.logger.error("Unexpected status code while posting impressions: #{response.status}." \
          ' - Check your API key and base URI')
          raise 'Split SDK failed to connect to backend to post impressions'
        end
      end

      def post_count(impressions_count)
        if impressions_count.nil? || impressions_count[:pf].empty?
          @config.split_logger.log_if_debug('No impressions count to send')
          return
        end

        start = Time.now

        response = post_api("#{@config.events_uri}/testImpressions/count", @api_key, impressions_count)

        if response.success?
          @config.split_logger.log_if_debug("Impressions count sent: #{impressions_count[:pf].length}")

          bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
          @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::IMPRESSION_COUNT_SYNC, bucket)
          @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::IMPRESSION_COUNT_SYNC, (Time.now.to_f * 1000.0).to_i)
        else
          @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::IMPRESSION_COUNT_SYNC, response.status)

          @config.logger.error("Unexpected status code while posting impressions count: #{response.status}." \
          ' - Check your API key and base URI')
          raise 'Split SDK failed to connect to backend to post impressions'
        end
      end

      def total_impressions(impressions)
        return 0 if impressions.nil?

        impressions.reduce(0) do |impressions_count, impression|
          impressions_count += impression[:i].length
        end
      end

      private

      def impressions_headers
        {
          'SplitSDKImpressionsMode' => @config.impressions_mode.to_s
        }
      end
    end
  end
end
