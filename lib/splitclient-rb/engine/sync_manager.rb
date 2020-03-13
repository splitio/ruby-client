# frozen_string_literal: true

module SplitIoClient
  module Engine
    class SyncManager
      include SplitIoClient::Cache::Fetchers

      def initialize(
        repositories,
        api_key,
        config,
        sdk_blocker
      )
        metrics = Metrics.new(100, repositories[:metrics])
        split_fetcher = SplitFetcher.new(repositories[:splits], api_key, metrics, config, sdk_blocker)
        segment_fetcher = SegmentFetcher.new(repositories[:segments], api_key, metrics, config, sdk_blocker)
        sync_params = synchronizer_params(split_fetcher, segment_fetcher)

        @synchronizer = Synchronizer.new(repositories, api_key, config, sdk_blocker, sync_params)
        @sse_handler = SplitIoClient::SSE::SSEHandler.new(config, @synchronizer, repositories[:splits], repositories[:segments])
        @push_manager = PushManager.new(config, @sse_handler)
        @config = config
        @api_key = api_key
      end

      def start
        start_stream
      end

      private

      def start_poll
        @config.threads[:sync_manager_start_poll] = Thread.new do
          begin
            @synchronizer.start_periodic_fetch
            @synchronizer.start_periodic_data_recording
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      # Starts tasks if stream is enabled.
      def start_stream
        stream_start_thread
        stream_start_thread_forked if defined?(PhusionPassenger)

        stream_start_sse_thread
        stream_start_sse_thread_forked if defined?(PhusionPassenger)
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

      def stream_start_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| stream_start_thread if forked }
      end

      # Starts thread which connect to sse and after that fetch splits and segments once.
      def stream_start_sse_thread
        @config.threads[:sync_manager_start_sse] = Thread.new do
          begin
            connected = @push_manager.start_sse(@api_key)

            if connected
              @synchronizer.sync_all
              @sse_handler.start_workers
            else
              @synchronizer.start_periodic_fetch
              @sse_handler.stop_workers
            end
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      def stream_start_sse_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| stream_start_sse_thread if forked }
      end

      def synchronizer_params(split_fetcher, segment_fetcher)
        params = {}
        params[:split_fetcher] = split_fetcher
        params[:segment_fetcher] = segment_fetcher

        params
      end
    end
  end
end
