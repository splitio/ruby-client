# frozen_string_literal: true

module SplitIoClient
  module SSE
    class SSEHandler
      attr_reader :sse_client

      def initialize(config, synchronizer, splits_repository, segments_repository, notification_manager_keeper)
        @config = config
        @notification_manager_keeper = notification_manager_keeper
        @splits_worker = SplitIoClient::SSE::Workers::SplitsWorker.new(synchronizer, config, splits_repository)
        @segments_worker = SplitIoClient::SSE::Workers::SegmentsWorker.new(synchronizer, config, segments_repository)
        @notification_processor = SplitIoClient::SSE::NotificationProcessor.new(config, @splits_worker, @segments_worker)

        @on = { connected: ->(_) {}, disconnect: ->(_) {} }

        yield self if block_given?
      end

      def start(token_jwt, channels)
        url = "#{@config.streaming_service_url}?channels=#{channels}&v=1.1&accessToken=#{token_jwt}"

        @sse_client = SSE::EventSource::Client.new(url, @config) do |client|
          client.on_event { |event| handle_incoming_message(event) }
          client.on_connected { process_connected }
          client.on_disconnect { process_disconnect }
        end
      end

      def stop
        @sse_client&.close
        @sse_client = nil
      end

      def connected?
        @sse_client&.connected? || false
      end

      def start_workers
        @splits_worker.start
        @segments_worker.start
      end

      def stop_workers
        @splits_worker.stop
        @segments_worker.stop
      end

      def on_connected(&action)
        @on[:connected] = action
      end

      def on_disconnect(&action)
        @on[:disconnect] = action
      end

      def process_disconnect
        @on[:disconnect].call
      end

      private

      def process_connected
        @on[:connected].call
      end

      def handle_incoming_message(notification)
        if notification.occupancy?
          @notification_manager_keeper.handle_incoming_occupancy_event(notification)
        else
          @notification_processor.process(notification)
        end
      end
    end
  end
end
