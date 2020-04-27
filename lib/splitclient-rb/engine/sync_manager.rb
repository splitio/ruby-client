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
        notification_manager_keeper = SplitIoClient::SSE::NotificationManagerKeeper.new(config) do |manager|
          manager.on_occupancy { |publisher_available| process_occupancy(publisher_available) }
          manager.on_push_shutdown { process_push_shutdown }
        end
        @sse_handler = SplitIoClient::SSE::SSEHandler.new(
          config,
          @synchronizer,
          repositories[:splits],
          repositories[:segments],
          notification_manager_keeper
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
        @config.logger.debug("Starting push mode ...")
        stream_start_thread
        @synchronizer.start_periodic_data_recording

        stream_start_sse_thread
      end

      def start_poll
        @config.logger.debug("Starting polling mode ...")
        @synchronizer.start_periodic_fetch
        @synchronizer.start_periodic_data_recording
      rescue StandardError => e
        @config.logger.error("start_poll error : #{e.inspect}")
      end

      # Starts thread which fetch splits and segments once and trigger task to periodic data recording.
      def stream_start_thread
        @config.threads[:sync_manager_start_stream] = Thread.new do
          begin
            @synchronizer.sync_all            
          rescue StandardError => e
            @config.logger.error("stream_start_thread error : #{e.inspect}")
          end
        end
      end

      # Starts thread which connect to sse and after that fetch splits and segments once.
      def stream_start_sse_thread
        @config.threads[:sync_manager_start_sse] = Thread.new do
          begin
            @push_manager.start_sse
          rescue StandardError => e
            @config.logger.error("stream_start_sse_thread error : #{e.inspect}")
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
      rescue StandardError => e
        @config.logger.error("process_connected error: #{e.inspect}")
      end

      def process_disconnect
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
      rescue StandardError => e
        @config.logger.error("process_disconnect error: #{e.inspect}")
      end

      def process_occupancy(push_enable)
        process_disconnect unless push_enable
        process_connected if push_enable
      rescue StandardError => e
        @config.logger.error("process_occupancy error: #{e.inspect}")
      end

      def process_push_shutdown
        @push_manager.stop_sse
        process_disconnect
      rescue StandardError => e
        @config.logger.error("process_push_shutdown error: #{e.inspect}")
      end
    end
  end
end
