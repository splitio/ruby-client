module SplitIoClient
  module Api
    class Events < Client
      def initialize(api_key)
        @api_key = api_key
      end

      def post(events)
        if events.empty?
          SplitIoClient.configuration.logger.debug('No events to report') if SplitIoClient.configuration.debug_enabled
          return
        end

        events.each_slice(SplitIoClient.configuration.events_queue_size) do |events_slice|
          result = post_api(
            "#{SplitIoClient.configuration.events_uri}/events/bulk",
            @api_key,
            events_slice.map { |event| formatted_event(event[:e]) },
            'SplitSDKMachineIP' => events_slice[0][:m][:i],
            'SplitSDKMachineName' => events_slice[0][:m][:n],
            'SplitSDKVersion' => events_slice[0][:m][:s]
          )

          if response.success?
            SplitLogger.log_if_debug("Events reported: #{events_slice.size}")
          else
            SplitLogger.log_error("Unexpected status code while posting events: #{response.status}." \
            " - Check your API key and base URI")
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
          timestamp: event[:timestamp].to_i
        }
      end
    end
  end
end
