# frozen_string_literal: true

module SplitIoClient
  module SSE
    class SSEHandler
      attr_reader :sse_client

      def initialize(config,
                     splits_worker,
                     segments_worker,
                     sse_client)
        @config = config
        @splits_worker = splits_worker
        @segments_worker = segments_worker
        @sse_client = sse_client
      end

      def start(token_jwt, channels)
        @sse_client.start("#{@config.streaming_service_url}?channels=#{channels}&v=1.1&accessToken=#{token_jwt}")
      end

      def stop
        @sse_client.close(Constants::PUSH_FORCED_STOP)
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
    end
  end
end
