# frozen_string_literal: true

module SplitIoClient
  module Engine
    class AuthApiClient
      def authenticate(api_key)
        # TODO: implement this method
        { push_enabled: true, api_key: api_key, token: 'token-fake', channels: 'channel-fake', status_code: 200 }
      end
    end
  end
end
