# frozen_string_literal: true

module SplitIoClient
  module Engine
    class AuthApiClient
      def authenticate(api_key)
        # TODO: implement this method
        { pushEnabled: true, api_key: api_key, token: 'token-fake', channels: 'channel-fake' }
      end
    end
  end
end
