# frozen_string_literal: true

module SplitIoClient
  module SSE
    class SSEHandler
      attr_reader :sse_client

      def initialize(config, synchronizer, repositories, notification_manager_keeper, api_key)
        @config = config
        @notification_manager_keeper = notification_manager_keeper
        @splits_worker = SplitIoClient::SSE::Workers::SplitsWorker.new(synchronizer, config, repositories[:splits])
        @segments_worker = SplitIoClient::SSE::Workers::SegmentsWorker.new(synchronizer, config, repositories[:segments])
        @notification_processor = SplitIoClient::SSE::NotificationProcessor.new(config, @splits_worker, @segments_worker)
        @sse_client = SSE::EventSource::Client.new(@config, api_key) do |client|
          client.on_event { |event| handle_incoming_message(event) }
          client.on_action { |action| process_action(action) }
        end

        @on = { action: ->(_) {} }

        yield self if block_given?
      end

      def start(token_jwt, channels)
        url = "#{@config.streaming_service_url}?channels=#{channels}&v=1.1&accessToken=#{token_jwt}"
        @sse_client.start(url)
      end

      def stop
        @sse_client.close
        stop_workers
      rescue StandardError => e
        @config.logger.debug("SSEHandler stop error: #{e.inspect}") if @config.debug_enabled
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

      def on_action(&action)
        @on[:action] = action
      end

      private

      def process_action(action)
        @on[:action].call(action)
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
