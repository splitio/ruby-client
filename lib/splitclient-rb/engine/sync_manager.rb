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

      def start_stream
        stream_start_thread
        stream_start_thread_forked if defined?(PhusionPassenger)

        stream_start_sse_thread
        stream_start_sse_thread_forked if defined?(PhusionPassenger)
      end

      def stream_start_thread
        @config.threads[:sync_manager_start] = Thread.new do
          begin
            @synchronizer.sync_all
            @synchronizer.start_periodic_data_recording
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      def stream_start_sse_thread
        @config.threads[:sync_manager_start_sse] = Thread.new do
          begin
            @push_manager.start_sse(@api_key)
            @synchronizer.sync_all
            start_workers
          rescue StandardError => error
            @config.logger.error(error)
          end
        end
      end

      def stream_start_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| start_thread if forked }
      end

      def stream_start_sse_thread_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| start_sse_thread if forked }
      end

      def start_workers
        @splits_worker.start
        @segments_worker.start
        @control_worker.start
      end

      def fetchers
        fetchers[:split] = @split_fetcher
        fetchers[:segment] = @segment_fetcher
      end
    end
  end
end
