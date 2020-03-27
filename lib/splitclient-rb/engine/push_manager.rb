# frozen_string_literal: true

module SplitIoClient
  module Engine
    class PushManager
      def initialize(config, sse_handler, api_key)
        @config = config
        @sse_handler = sse_handler
        @auth_api_client = AuthApiClient.new(@config)
        @api_key = api_key
      end

      def start_sse
        response = @auth_api_client.authenticate(@api_key)

        if response[:push_enabled]
          @sse_handler.start(response[:token], response[:channels])
          schedule_next_token_refresh(response[:exp], response[:token])
        else
          stop_sse
        end

        schedule_next_token_refresh(@config.auth_retry_back_off_base, response[:token]) if response[:retry]
      rescue StandardError => e
        puts e.inspect
      end

      def stop_sse
        @sse_handler.process_disconnect if @sse_handler.sse_client.nil?
        @sse_handler.stop
      end

      private

      def schedule_next_token_refresh(time, token)
        @config.threads[:schedule_next_token_refresh] = Thread.new do
          sleep(time)
          stop_sse
          start_sse
        end
      end
    end
  end
end
