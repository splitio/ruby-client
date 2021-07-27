# frozen_string_literal: true

module SplitIoClient
  module Engine
    class SyncManager
      SYNC_MODE_STREAMING = 0
      SYNC_MODE_POLLING = 1

      def initialize(
        repositories,
        api_key,
        config,
        synchronizer,
        telemetry_runtime_producer,
        sdk_blocker,
        telemetry_synchronizer
      )
        @synchronizer = synchronizer
        notification_manager_keeper = SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer) do |manager|
          manager.on_action { |action| process_action(action) }
        end
        @sse_handler = SSE::SSEHandler.new(
          { config: config, api_key: api_key },
          @synchronizer,
          repositories,
          notification_manager_keeper,
          telemetry_runtime_producer
        ) do |handler|
          handler.on_action { |action| process_action(action) }
        end

        @push_manager = PushManager.new(config, @sse_handler, api_key, telemetry_runtime_producer)
        @sse_connected = Concurrent::AtomicBoolean.new(false)
        @config = config
        @telemetry_runtime_producer = telemetry_runtime_producer
        @sdk_blocker = sdk_blocker
        @telemetry_synchronizer = telemetry_synchronizer
      end

      def start
        if @config.streaming_enabled
          start_stream
          start_stream_forked if defined?(PhusionPassenger)
        elsif @config.standalone?
          start_poll
        end

        synchronize_telemetry_config
      end

      private

      # Starts tasks if stream is enabled.
      def start_stream
        @config.logger.debug('Starting push mode ...')
        @synchronizer.sync_all
        @synchronizer.start_periodic_data_recording

        start_sse_connection_thread
      end

      def start_poll
        @config.logger.debug('Starting polling mode ...')
        @synchronizer.start_periodic_fetch
        @synchronizer.start_periodic_data_recording
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)
      rescue StandardError => e
        @config.logger.error("start_poll error : #{e.inspect}")
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
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_STREAMING)
      end

      def process_subsystem_down
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)
      end

      def process_push_shutdown
        @push_manager.stop_sse
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)
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
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_STREAMING)
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
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)

        if reconnect
          @synchronizer.sync_all
          @push_manager.start_sse
        end
      rescue StandardError => e
        @config.logger.error("process_disconnect error: #{e.inspect}")
      end

      def record_telemetry(type, data)
        @telemetry_runtime_producer.record_streaming_event(type, data)
      end

      def synchronize_telemetry_config
        @config.threads[:telemetry_config_sender] = Thread.new do
          begin
            @sdk_blocker.wait_unitil_internal_ready unless @config.consumer?
            @telemetry_synchronizer.synchronize_config
          rescue SplitIoClient::SDKShutdownException
            @telemetry_synchronizer.synchronize_config
            @config.logger.info('Posting Telemetry config due to shutdown')
          end
        end
      end
    end
  end
end
