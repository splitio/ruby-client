# frozen_string_literal: true

module SplitIoClient
  module Engine
    class SyncManager
      def initialize(
        repositories,
        api_key,
        config,
        synchronizer
      )
        @synchronizer = synchronizer
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
          handler.on_disconnect { |reconnect| process_disconnect(reconnect) }
        end

        @push_manager = PushManager.new(config, @sse_handler, api_key)
        @sse_connected = Concurrent::AtomicBoolean.new(false)
        @config = config
      end

      def start
        if @config.streaming_enabled
          start_stream
          start_stream_forked if defined?(PhusionPassenger)
        elsif @config.standalone?
          start_poll
        end
      end

      private

      # Starts tasks if stream is enabled.
      def start_stream
        @config.logger.debug('Starting push mode ...')
        stream_start_thread
        @synchronizer.start_periodic_data_recording

        stream_start_sse_thread
      end

      def start_poll
        @config.logger.debug('Starting polling mode ...')
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

      def start_stream_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| start_stream if forked }
      end

      def process_connected
        if @sse_connected.value
          @config.logger.debug('Streaming already connected.')
          return
        end

        @sse_connected.make_true
        @synchronizer.stop_periodic_fetch
        @synchronizer.sync_all
        @sse_handler.start_workers
      rescue StandardError => e
        @config.logger.error("process_connected error: #{e.inspect}")
      end

      def process_disconnect(reconnect)
        unless @sse_connected.value
          @config.logger.debug('Streaming already disconnected.')
          return
        end

        @sse_connected.make_false
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch

        if reconnect
          @synchronizer.sync_all
          @push_manager.start_sse
        end
      rescue StandardError => e
        @config.logger.error("process_disconnect error: #{e.inspect}")
      end

      def process_occupancy(push_enable)
        if push_enable
          @synchronizer.stop_periodic_fetch
          @synchronizer.sync_all
          @sse_handler.start_workers
          return
        end

        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
      rescue StandardError => e
        @config.logger.error("process_occupancy error: #{e.inspect}")
      end

      def process_push_shutdown
        @push_manager.stop_sse
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
      rescue StandardError => e
        @config.logger.error("process_push_shutdown error: #{e.inspect}")
      end
    end
  end
end
