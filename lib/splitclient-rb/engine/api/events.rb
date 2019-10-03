# frozen_string_literal: true

module SplitIoClient
  module Api
    class Events < Client
      def initialize(api_key, config)
        super(config)
        @api_key = api_key
        @events_post_uri = "#{@config.events_uri}/events/bulk"
      end

      def post(events)
        if events.empty?
          @config.split_logger.log_if_debug('No events to report')
          return
        end

        events.each_slice(@config.events_queue_size) do |events_slice|
          response = post_api(@events_post_uri, @api_key, events_slice.map { |event| formatted_event(event) })

          if response.success?
            @config.split_logger.log_if_debug("Events reported: #{events_slice.size}")
          else
            @config.logger.error("Unexpected status code while posting events: #{response.status}." \
            ' - Check your API key and base URI')
            raise 'Split SDK failed to connect to backend to post events'
          end
        end
      end

      private

      def formatted_event(event)
        event.merge(
          value: event[:value].to_f,
          timestamp: event[:timestamp].to_i
        )
      end
    end
  end
end
