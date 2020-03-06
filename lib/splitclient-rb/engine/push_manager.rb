# frozen_string_literal: true

module SplitIoClient
  module Engine
    class PushManager
      def initialize(config, sse_handler)
        @config = config
        @sse_handler = sse_handler
        @auth_api_client = AuthApiClient.new
      end

      def start_sse(api_key)
        token = @auth_api_client.authenticate(api_key)
        @sse_client = @sse_handler.start('www.ably.io', token['jwt'], token['channels'])
        schedule_next_token_refresh(token)
      end

      def stop_sse
        @sse_client.close
      end

      private

      def schedule_next_token_refresh(token)
        # TODO: implement this method
      end
    end
  end
end