# frozen_string_literal: true

module SplitIoClient
  module Engine
    class PushManager
      def initialize(config, sse_handler)
        @config = config
        @sse_handler = sse_handler
        @auth_api_client = AuthApiClient.new(@config)
      end

      def start_sse(api_key)
        response = @auth_api_client.authenticate(api_key)

        if response[:push_enabled]
          @sse_handler.start(response[:token], response[:channels])
          schedule_next_token_refresh(@config.auth_retry_back_off_base, response[:token])
        else
          stop_sse
        end

        schedule_next_token_refresh(@config.auth_retry_back_off_base, response[:token]) if response[:retry]

        @sse_handler&.connected? || false
      end

      def stop_sse
        @sse_handler&.stop
      end

      private

      def schedule_next_token_refresh(back_off, token)
        @config.threads[:schedule_next_token_refresh] = Thread.new do
          sleep(back_off)

          stop_sse
          start_sse(token)
        end
      end
    end
  end
end
