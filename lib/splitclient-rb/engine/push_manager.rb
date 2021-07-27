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
      end

      def start_sse
        response = @auth_api_client.authenticate(@api_key)

        @config.logger.debug("Auth service response push_enabled: #{response[:push_enabled]}") if @config.debug_enabled

        if response[:push_enabled] && @sse_handler.start(response[:token], response[:channels])
          schedule_next_token_refresh(response[:exp])
          @back_off.reset
          record_telemetry(response[:exp])

          return true
        end

        stop_sse

        schedule_next_token_refresh(@back_off.interval) if response[:retry]
        false
      rescue StandardError => e
        @config.logger.error("start_sse: #{e.inspect}")
      end

      def stop_sse
        @sse_handler.process_disconnect if @sse_handler.sse_client.nil?
        @sse_handler.stop
        SplitIoClient::Helpers::ThreadHelper.stop(:schedule_next_token_refresh, @config)
      end

      private

      def schedule_next_token_refresh(time)
        @config.threads[:schedule_next_token_refresh] = Thread.new do
          begin
            @config.logger.debug("schedule_next_token_refresh refresh in #{time} seconds.") if @config.debug_enabled
            sleep(time)
            @config.logger.debug('schedule_next_token_refresh starting ...') if @config.debug_enabled
            @sse_handler.stop
            start_sse
          rescue StandardError => e
            @config.logger.debug("schedule_next_token_refresh error: #{e.inspect}") if @config.debug_enabled
          end
        end
      end

      def record_telemetry(time)
        data = (Time.now.to_f * 1000.0).to_i + (time * 1000.0).to_i
        @telemetry_runtime_producer.record_streaming_event(Telemetry::Domain::Constants::TOKEN_REFRESH, data)
      end
    end
  end
end
