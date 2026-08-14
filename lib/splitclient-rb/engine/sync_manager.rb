# frozen_string_literal: true

module SplitIoClient
  module Engine
    class SyncManager
      SYNC_MODE_STREAMING = 0
      SYNC_MODE_POLLING = 1

      def initialize(config, synchronizer, telemetry_runtime_producer, telemetry_synchronizer,
                     status_manager, sse_handler, push_manager, status_queue)
        @config = config
        @synchronizer = synchronizer
        @telemetry_runtime_producer = telemetry_runtime_producer
        @telemetry_synchronizer = telemetry_synchronizer
        @status_manager = status_manager
        @sse_handler = sse_handler
        @push_manager = push_manager
        @status_queue = status_queue
        @sse_connected = Concurrent::AtomicBoolean.new(false)
        @reconnect_policy = Engine::ReconnectPolicy.new(config, status_queue)
      end

      def start
        start_thread
        PhusionPassenger.on_event(:starting_worker_process) { |forked| start_thread if forked } if defined?(PhusionPassenger)
      end

      def start_consumer
        start_consumer_thread
        PhusionPassenger.on_event(:starting_worker_process) { |forked| start_consumer_thread if forked } if defined?(PhusionPassenger)
      end

      private

      def start_thread
        @config.threads[:start_sdk] = Thread.new do
          sleep(0.5) until @synchronizer.sync_all(false)

          @status_manager.ready!
          @telemetry_synchronizer.synchronize_config
          @synchronizer.start_periodic_data_recording
          connected = false

          if @config.streaming_enabled
            @config.logger.debug('Starting Streaming mode ...') if @config.debug_enabled
            start_push_status_monitor
            connected = @push_manager.start_sse
          end

          unless connected
            @config.logger.debug('Starting Polling mode ...') if @config.debug_enabled
            @synchronizer.start_periodic_fetch
            record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)
          end
        end
      end

      def start_consumer_thread
        @config.threads[:start_sdk_consumer] = Thread.new do
          @status_manager.ready!
          @telemetry_synchronizer.synchronize_config
          @synchronizer.start_periodic_data_recording
        end
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
          @config.logger.debug('Streaming already connected.') if @config.debug_enabled
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

      def process_forced_stop
        unless @sse_connected.value
          @config.logger.debug('Streaming already disconnected.') if @config.debug_enabled
          return
        end

        @sse_connected.make_false
        @synchronizer.start_periodic_fetch
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)
      rescue StandardError => e
        @config.logger.error("process_connected error: #{e.inspect}")
      end

      def process_disconnect(reconnect)
        return unless @reconnect_policy.actionable?(@sse_connected.value, reconnect)

        @reconnect_policy.record_disconnect
        @sse_connected.make_false
        @sse_handler.stop_workers
        @synchronizer.start_periodic_fetch
        record_telemetry(Telemetry::Domain::Constants::SYNC_MODE, SYNC_MODE_POLLING)

        reconnect_streaming if reconnect
      rescue StandardError => e
        @config.logger.error("process_disconnect error: #{e.inspect}")
        @reconnect_policy.release if reconnect
      end

      def reconnect_streaming
        wait_interval = @reconnect_policy.interval
        log_if_debug("Retrying streaming connection in: #{wait_interval} seconds")
        sleep(wait_interval)
        @push_manager.stop_sse
        @synchronizer.sync_all

        # Only discard queued errors once streaming is actually back up. If the retry
        # failed, those errors are still the only thing that will drive the next
        # attempt, so they must be left alone.
        @reconnect_policy.discard_stale_errors if @push_manager.start_sse
      ensure
        @reconnect_policy.release
      end

      def record_telemetry(type, data)
        @telemetry_runtime_producer.record_streaming_event(type, data)
      end

      def start_push_status_monitor
        @config.threads[:push_status_handler] = Thread.new do
          @config.logger.debug('Starting push status handler ...') if @config.debug_enabled
          incoming_push_status_handler
        end
      end

      def incoming_push_status_handler
        while (status = @status_queue.pop)
          @config.logger.debug("Push status handler dequeue #{status}") if @config.debug_enabled

          case status
          when Constants::PUSH_CONNECTED
            # Deliberately not resetting the back off here. Whether this connection
            # earns a reset depends on how long it survives, which is only known once
            # it drops -- see ReconnectPolicy#record_disconnect.
            @reconnect_policy.connected
            process_connected
          when Constants::PUSH_RETRYABLE_ERROR
            process_disconnect(true)
          when Constants::PUSH_FORCED_STOP
            process_forced_stop
          when Constants::PUSH_NONRETRYABLE_ERROR
            process_disconnect(false)
          when Constants::PUSH_SUBSYSTEM_DOWN
            process_subsystem_down
          when Constants::PUSH_SUBSYSTEM_READY
            process_subsystem_ready
          when Constants::PUSH_SUBSYSTEM_OFF
            process_push_shutdown
          else
            log_if_debug('Incorrect push status type.')
          end
        end
      rescue StandardError => e
        @config.logger.error("Push status handler error: #{e.inspect}")
      end

      # Was defined on the enclosing module, so every call raised NoMethodError and
      # killed the push status handler thread (its rescue sits outside the loop).
      def log_if_debug(msg)
        @config.logger.debug(msg) if @config.debug_enabled
      end
    end
  end
end
