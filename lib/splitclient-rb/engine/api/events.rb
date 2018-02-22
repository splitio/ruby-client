module SplitIoClient
  module Api
    class Events < Client
      def initialize(api_key, config, events)
        @config = config
        @api_key = api_key
        @events = events
      end

      def post
        if @events.empty?
          @config.logger.debug('No events to report') if @config.debug_enabled
          return
        end

        @events.each_slice(@config.events_queue_size) do |event_slice|
          result = post_api(
            "#{@config.events_uri}/events/bulk",
            @config,
            @api_key,
            event_slice.map { |event| formatted_event(event[:e]) },
            'SplitSDKMachineIP' => event_slice[0][:m][:i],
            'SplitSDKMachineName' => event_slice[0][:m][:n],
            'SplitSDKVersion' => event_slice[0][:m][:s]
          )

          if (200..299).include? result.status
            @config.logger.debug("Events reported: #{event_slice.size}") if @config.debug_enabled
          else
            @config.logger.error("Unexpected status code while posting events: #{result.status}")
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
          timestamp: event[:timestamp].to_i
        }
      end
    end
  end
end
