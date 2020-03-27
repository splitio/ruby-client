# frozen_string_literal: true

require 'jwt'
require 'cgi'

module SplitIoClient
  module Engine
    class AuthApiClient
      EXPIRATION_RATE = 600

      def initialize(config)
        @config = config
        @api_client = SplitIoClient::Api::Client.new(@config)
      end

      def authenticate(api_key)
        response = @api_client.get_api(@config.auth_service_url, api_key)

        return process_success(response) if response.success?

        if response.status >= 400 && response.status < 500
          @config.logger.debug("Problem to connect to: #{@config.auth_service_url}. Response status: #{response.status}")

          return { push_enabled: false, retry: false }
        end

        @config.logger.debug("Problem to connect to: #{@config.auth_service_url}. Response status: #{response.status}")
        { push_enabled: false, retry: true }
      end

      private

      def expiration(token_decoded)
        exp = token_decoded[0]['exp']

        (exp - EXPIRATION_RATE) - Time.now.getutc.to_i unless exp.nil?
      rescue StandardError => e
        @config.logger.error("Error getting token expiration: #{e.inspect}")
      end

      def channels(token_decoded)
        capability = token_decoded[0]['x-ably-capability']
        channels_hash = JSON.parse(capability)
        channels_string = channels_hash.keys.join(',')

        CGI.escape(channels_string)
      end

      def decode_token(token)
        JWT.decode token, nil, false
      end

      def process_success(response)
        @config.logger.debug("Success connection to: #{@config.auth_service_url}")

        body_json = JSON.parse(response.body, symbolize_names: true)
        push_enabled = body_json[:pushEnabled]
        token = body_json[:token]

        if push_enabled
          decoded_token = decode_token(token)
          channels = channels(decoded_token)
          exp = expiration(decoded_token)
        end

        { push_enabled: push_enabled, token: token, channels: channels, exp: exp, retry: false }
      end
    end
  end
end
