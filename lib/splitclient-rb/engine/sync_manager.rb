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
        @config = config
        @api_key = api_key
        @metrics = Metrics.new(100, repositories[:metrics])
        @split_fetcher = SplitFetcher.new(repositories[:splits], api_key, @metrics, config, sdk_blocker)
        @segment_fetcher = SegmentFetcher.new(repositories[:segments], api_key, @metrics, config, sdk_blocker)
        @splits_worker = SplitIoClient::SSE::Workers::SplitsWorker.new(@split_fetcher, config, repositories[:splits])
        @segments_worker = SplitIoClient::SSE::Workers::SegmentsWorker.new(@segment_fetcher, config, repositories[:segments])
        @control_worker = SplitIoClient::SSE::Workers::ControlWorker.new(config)
        @synchronizer = Synchronizer.new(repositories, api_key, config, sdk_blocker, fetchers)

        sse_handler = SplitIoClient::SSE::SSEHandler.new(@config, @splits_worker, @segments_worker, @control_worker)
        @push_manager = PushManager.new(@config, sse_handler)
      end

      def start
        start_stream
      end

      private

      def start_poll
        @config.threads[:sync_manager_start_poll] = Thread.new do
          begin
            start_fetching
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
              start_workers
            else
              start_fetching
            end
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      def stream_start_sse_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| stream_start_sse_thread if forked }
      end

      def start_workers
        @splits_worker.start
        @segments_worker.start
        @control_worker.start
      end

      def start_fetching
        @split_fetcher.call
        @segment_fetcher.call
      end

      def fetchers
        fetchers[:split] = @split_fetcher
        fetchers[:segment] = @segment_fetcher
      end
    end
  end
end
