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
          manager.on_action { |action| process_action(action) }
        end
        @sse_handler = SplitIoClient::SSE::SSEHandler.new(
          config,
          @synchronizer,
          repositories[:splits],
          repositories[:segments],
          notification_manager_keeper
        ) do |handler|
          handler.on_action { |action| process_action(action) }
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
        sync_all_thread
        @synchronizer.start_periodic_data_recording

        start_sse_connection_thread
      end

      def start_poll
        @config.logger.debug('Starting polling mode ...')
        @synchronizer.start_periodic_fetch
        @synchronizer.start_periodic_data_recording
      rescue StandardError => e
        @config.logger.error("start_poll error : #{e.inspect}")
      end

      # Starts thread which fetch splits and segments once and trigger task to periodic data recording.
      def sync_all_thread
        @config.threads[:sync_manager_start_stream] = Thread.new do
          begin
            @synchronizer.sync_all
          rescue StandardError => e
            @config.logger.error("sync_all_thread error : #{e.inspect}")
          end
        end
      end

      # Starts thread which connect to sse and after that fetch splits and segments once.
      def start_sse_connection_thread
        @config.threads[:sync_manager_start_sse] = Thread.new do
          begin
            connected = @push_manager.start_sse
            @synchronizer.start_periodic_fetch unless connected
          rescue StandardError => e
            @config.logger.error("start_sse_connection_thread error : #{e.inspect}")
          end
        end
      end

      def start_stream_forked
        PhusionPassenger.on_event(:starting_worker_process) { |forked| start_stream if forked }
      end

      def process_action(action)
        case action
        when Constants::PUSH_CONNECTED
          process_connected
        when Constants::PUSH_RETRYABLE_ERROR
          process_disconnect(true)
        when Constants::PUSH_NONRETRYABLE_ERROR
          process_disconnect(false)
        when Constants::PUSH_SUBSYSTEM_DOWN
          process_subsystem_down
        when Constants::PUSH_SUBSYSTEM_READY
          process_subsystem_ready
        when Constants::PUSH_SUBSYSTEM_OFF
          process_push_shutdown
        else
          @config.logger.debug('Incorrect action type.')
        end
      rescue StandardError => e
        @config.logger.error("process_action error: #{e.inspect}")
      end

      def process_subsystem_ready
        @synchronizer.stop_periodic_fetch
        @synchronizer.sync_all
        @sse_handler.start_workers
      end

      def process_subsystem_down
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
      end

      def process_push_shutdown
        @push_manager.stop_sse
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
      rescue StandardError => e
        @config.logger.error("process_push_shutdown error: #{e.inspect}")
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
    end
  end
end
