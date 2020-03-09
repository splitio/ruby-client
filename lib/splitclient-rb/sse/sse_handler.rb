# frozen_string_literal: true

module SplitIoClient
  module SSE
    class SSEHandler
      attr_reader :sse_client

      def initialize(config, splits_worker, segments_worker, control_worker)
        @config = config
        @splits_worker = splits_worker
        @segments_worker = segments_worker
        @control_worker = control_worker
      end

      def start(url_host, token_jwt, channels)
        url = "#{url_host}/event-stream?channels=#{channels}&v=1.1&key=#{token_jwt}"

        @sse_client = SSE::EventSource::Client.new(url, @config) do |client|
          client.on_event do |event|
            process_event(event)
          end

          client.on_error do |error|
            process_error(error)
          end
        end
      end

      def stop
        @sse_client.close if defined?(@sse_client)
      end

      def connected?
        @sse_client&.connected?
      end

      private

      def process_event(event)
        case event.data['type']
        when SSE::EventSource::EventTypes::SPLIT_UPDATE
          split_update_notification(event)
        when SSE::EventSource::EventTypes::SPLIT_KILL
          split_kill_notification(event)
        when SSE::EventSource::EventTypes::SEGMENT_UPDATE
          segment_update_notification(event)
        when SSE::EventSource::EventTypes::CONTROL
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
        @splits_worker.add_to_queue(event.data['changeNumber'])
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

        @segments_worker.add_to_queue(change_number, segment_name)
      end

      def control_notification(event)
        @config.logger.debug("CONTROL notification received: #{event}")
      end
    end
  end
end
