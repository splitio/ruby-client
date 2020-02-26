# frozen_string_literal: true

module SplitIoClient
  module SSE
    class SSEHandler
      attr_reader :sse_client

      def initialize(config, options, splits_worker, segment_update_worker)
        @config = config
        @options = options
        @splits_worker = splits_worker
        @segment_update_worker = segment_update_worker

        # TODO: remove environment condition
        @sse_client = start_sse_client unless ENV['SPLITCLIENT_ENV'] == 'test'
      end

      private

      def start_sse_client
        url = "#{@options[:url_host]}/event-stream?channels=#{@options[:channels]}&v=1.1&key=#{@options[:key]}"

        sse_client = SSE::EventSource::Client.new(url, @config) do |client|
          client.on_event do |event|
            process_event(event)
          end

          client.on_error do |error|
            process_error(error)
          end
        end

        sse_client
      end

      def process_event(event)
        case event.data['type']
        when EventTypes::SPLIT_UPDATE
          split_update_notification(event)
        when EventTypes::SPLIT_KILL
          split_kill_notification(event)
        when EventTypes::SEGMENT_UPDATE
          segment_update_notification(event)
        when EventTypes::CONTROL
          control_notification(event)
        else
          @config.logger.error("Incorrect event type: #{event}")
        end
      end

      def process_error(error)
        @config.logger.error("SSE::EventSource::Client error: #{error}")
      end

      def split_update_notification(event)
        @config.logger.debug("SPLIT UPDATE notification received: #{event}")
        @splits_worker.add_to_adapter(event.data['changeNumber'])
      end

      def split_kill_notification(event)
        @config.logger.debug("SPLIT KILL notification received: #{event}")
        change_number = event.data['changeNumber']
        default_treatment = event.data['defaultTreatment']
        split_name = event.data['splitName']

        @splits_worker.kill_split(change_number, split_name, default_treatment)
      end

      def segment_update_notification(event)
        @config.logger.debug("SEGMENT UPDATE notification received: #{event}")
        change_number = event.data['changeNumber']
        segment_name = event.data['segmentName']

        @segment_update_worker.add_to_adapter(change_number, segment_name)
      end

      def control_notification(event)
        @config.logger.debug("CONTROL notification received: #{event}")
      end
    end
  end
end
