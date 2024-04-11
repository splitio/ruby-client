# frozen_string_literal: true

module SplitIoClient
  module Api
    class Events < Client
      def initialize(api_key, config, telemetry_runtime_producer, request_decorator)
        super(config, request_decorator)
        @api_key = api_key
        @telemetry_runtime_producer = telemetry_runtime_producer
      end

      def post(events)
        if events.empty?
          @config.split_logger.log_if_debug('No events to report')
          return
        end

        start = Time.now

        events.each_slice(@config.events_queue_size) do |events_slice|
          response = post_api(
            "#{@config.events_uri}/events/bulk",
            @api_key,
            events_slice.map { |event| formatted_event(event[:e]) }
          )

          if response.success?
            @config.split_logger.log_if_debug("Events reported: #{events_slice.size}")

            bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
            @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::EVENT_SYNC, bucket)
            @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::EVENT_SYNC, (Time.now.to_f * 1000.0).to_i)
          else
            @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::EVENT_SYNC, response.status)

            @config.logger.error("Unexpected status code while posting events: #{response.status}." \
            ' - Check your API key and base URI')
            raise 'Split SDK failed to connect to backend to post events'
          end
        end
      end

      private

      def formatted_event(event)
        {
          key: event[:key],
          trafficTypeName: event[:trafficTypeName],
          eventTypeId: event[:eventTypeId],
          value: event[:value].to_f,
          timestamp: event[:timestamp].to_i,
          properties: event[:properties]
        }
      end
    end
  end
end
