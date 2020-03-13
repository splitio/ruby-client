# frozen_string_literal: true

require 'jwt'

module SplitIoClient
  module Engine
    class AuthApiClient
      def initialize(config)
        @config = config
        @api_client = SplitIoClient::Api::Client.new(@config)
      end

      def authenticate(api_key)
        response = @api_client.get_api(@config.auth_service_url, api_key)

        if response.success?
          @config.logger.debug("Success connection to: #{@config.auth_service_url}")

          body_json = JSON.parse(response.body, symbolize_names: true)
          push_enabled = body_json[:pushEnabled]
          token = body_json[:token]

          return {
            push_enabled: push_enabled,
            token: token,
            channels: (channels(token) if push_enabled),
            retry: false
          }
        elsif response.status >= 400 && response.status < 500
          @config.logger.debug("Problem to connect to: #{@config.auth_service_url}. Response status: #{response.status}")

          return { push_enabled: false, retry: false }
        end

        @config.logger.debug("Problem to connect to: #{@config.auth_service_url}. Response status: #{response.status}")
        { push_enabled: false, retry: true }
      end

      private

      def channels(token)
        token_decoded = JWT.decode token, nil, false
        capability = token_decoded[0]['x-ably-capability']
        channels_hash = JSON.parse(capability)

        channels_hash.keys.join(',')
      end
    end
  end
end
