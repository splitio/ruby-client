# frozen_string_literal: true

module SplitIoClient
  module Engine
    class SyncManager
      include SplitIoClient::Cache::Fetchers

      def initialize(
        repositories,
        api_key,
        config,
        sdk_blocker,
        metrics
      )
        split_fetcher = SplitFetcher.new(repositories[:splits], api_key, metrics, config, sdk_blocker)
        segment_fetcher = SegmentFetcher.new(repositories[:segments], api_key, metrics, config, sdk_blocker)
        sync_params = { split_fetcher: split_fetcher, segment_fetcher: segment_fetcher }

        @synchronizer = Synchronizer.new(repositories, api_key, config, sdk_blocker, sync_params)

        @sse_handler = SplitIoClient::SSE::SSEHandler.new(
          config,
          @synchronizer,
          repositories[:splits],
          repositories[:segments]
        ) do |handler|
          handler.on_connected { process_connected }
          handler.on_disconnect { process_disconnect }
        end

        @push_manager = PushManager.new(config, @sse_handler, api_key)
        @config = config
      end

      def start
        if @config.streaming_enabled
          start_stream
        elsif @config.standalone?
          start_poll
        end
      end

      private

      # Starts tasks if stream is enabled.
      def start_stream
        stream_start_thread
        stream_start_thread_forked if defined?(PhusionPassenger)

        stream_start_sse_thread
        stream_start_sse_thread_forked if defined?(PhusionPassenger)
      end

      def start_poll
        @synchronizer.start_periodic_fetch
        @synchronizer.start_periodic_data_recording
      rescue StandardError => error
        @config.logger.error(error)
      end

      # Starts thread which fetch splits and segments once and trigger task to periodic data recording.
      def stream_start_thread
        @config.threads[:sync_manager_start_stream] = Thread.new do
          begin
            @synchronizer.sync_all
            @synchronizer.start_periodic_data_recording
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      # Starts thread which connect to sse and after that fetch splits and segments once.
      def stream_start_sse_thread
        @config.threads[:sync_manager_start_sse] = Thread.new do
          begin
            @push_manager.start_sse
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      def stream_start_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| stream_start_thread if forked }
      end

      def stream_start_sse_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| stream_start_sse_thread if forked }
      end

      def process_connected
        @synchronizer.stop_periodic_fetch
        @synchronizer.sync_all
        @sse_handler.start_workers
      end

      def process_disconnect
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
      end
    end
  end
end
