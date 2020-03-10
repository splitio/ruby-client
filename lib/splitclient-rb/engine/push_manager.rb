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
        response = @auth_api_client.authenticate(api_key)

        if response[:push_enabled] && response[:status_code] == 200
          @sse_handler.start(response[:token], response[:channels])
          schedule_next_token_refresh(response[:token])
        elsif response[:status_code] < 400 || response[:status_code] >= 500
          stop_sse
        end

        response[:push_enabled] && @sse_handler&.connected?
      end

      def stop_sse
        @sse_handler.stop
      end

      private

      def schedule_next_token_refresh(token)
        # TODO: implement this method
      end
    end
  end
end
