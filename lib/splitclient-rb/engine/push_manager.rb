# frozen_string_literal: true

module SplitIoClient
  module Engine
    class PushManager
      def initialize(config, sse_handler, api_key, telemetry_runtime_producer)
        @config = config
        @sse_handler = sse_handler
        @auth_api_client = AuthApiClient.new(@config, telemetry_runtime_producer)
        @api_key = api_key
        @back_off = Engine::BackOff.new(@config.auth_retry_back_off_base, 1)
        @telemetry_runtime_producer = telemetry_runtime_producer
        # Serializes start_sse: it is reachable from the push status handler thread and
        # from the token refresh thread concurrently.
        @start_sse_mutex = Mutex.new
      end

      def start_sse
        @start_sse_mutex.synchronize { start_sse_unsynchronized }
      end

      def stop_sse
        @sse_handler.stop
        SplitIoClient::Helpers::ThreadHelper.stop(:schedule_next_token_refresh, @config)
      rescue StandardError => e
        @config.logger.error(e.inspect)
      end

      private

      def start_sse_unsynchronized
        response = @auth_api_client.authenticate(@api_key)
        @config.logger.debug("Auth service response push_enabled: #{response[:push_enabled]}") if @config.debug_enabled

        unless response[:push_enabled]
          schedule_next_token_refresh(@back_off.interval) if response[:retry]
          return false
        end

        unless @sse_handler.start(response[:token], response[:channels])
          @config.logger.debug('Streaming server returned error') if @config.debug_enabled
          stop_sse
          return false
        end

        schedule_next_token_refresh(response[:exp])
        @back_off.reset
        record_telemetry(response[:exp])
        true
      rescue StandardError => e
        @config.logger.error("start_sse: #{e.inspect}")
      end

      def schedule_next_token_refresh(time)
        # Reap first: start_sse is reachable both from the push status handler thread and
        # from refresh_token_task itself, so without this an orphaned timer thread can
        # survive with no handle to cancel it and fire its own reconnect later.
        SplitIoClient::Helpers::ThreadHelper.reap(:schedule_next_token_refresh, @config)
        @config.threads[:schedule_next_token_refresh] = Thread.new { refresh_token_task(time) }
      end

      def refresh_token_task(time)
        @config.logger.debug("schedule_next_token_refresh refresh in #{time} seconds.") if @config.debug_enabled

        sleep(time)

        @config.logger.debug('schedule_next_token_refresh starting ...') if @config.debug_enabled
        @sse_handler.stop

        start_sse
      rescue StandardError => e
        @config.logger.debug("schedule_next_token_refresh error: #{e.inspect}") if @config.debug_enabled
      end

      def record_telemetry(time)
        data = (Time.now.to_f * 1000.0).to_i + (time * 1000.0).to_i
        @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::TOKEN_REFRESH, data)
      end
    end
  end
end
