# frozen_string_literal: true

require 'jwt'
require 'cgi'

module SplitIoClient
  module Engine
    class AuthApiClient
      def initialize(config)
        @config = config
        @api_client = SplitIoClient::Api::Client.new(@config)
      end

      def authenticate(api_key)
        response = @api_client.get_api(@config.auth_service_url, api_key)

        return process_success(response) if response.success?

        if response.status >= 400 && response.status < 500
          @config.logger.debug("Error connecting to: #{@config.auth_service_url}. Response status: #{response.status}")

          return { push_enabled: false, retry: false }
        end

        @config.logger.debug("Error connecting to: #{@config.auth_service_url}. Response status: #{response.status}")
        { push_enabled: false, retry: true }
      rescue StandardError => e
        @config.logger.debug("AuthApiClient error: #{e.inspect}")
        { push_enabled: false, retry: false }
      end

      private

      def expiration(token_decoded)
        exp = token_decoded[0]['exp']
        issued_at = token_decoded[0]['iat']

        exp - issued_at - SplitIoClient::Constants::EXPIRATION_RATE
      end

      def channels(token_decoded)
        capability = token_decoded[0]['x-ably-capability']
        channels_hash = JSON.parse(capability)
        channels_string = channels_hash.keys.join(',')
        channels_string = control_channels(channels_string)
        @config.logger.debug("Channels #{channels_string}") if @config.debug_enabled
        CGI.escape(channels_string)
      end

      def decode_token(token)
        JWT.decode token, nil, false
      end

      def process_success(response)
        @config.logger.debug("Success connection to: #{@config.auth_service_url}") if @config.debug_enabled

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

      def control_channels(channels_string)
        prefix = SplitIoClient::Constants::OCCUPANCY_CHANNEL_PREFIX
        control_pri = SplitIoClient::Constants::CONTROL_PRI
        control_sec = SplitIoClient::Constants::CONTROL_SEC
        channels_string = channels_string.gsub(control_pri, "#{prefix}#{control_pri}")
        channels_string = channels_string.gsub(control_sec, "#{prefix}#{control_sec}")
        channels_string
      end
    end
  end
end
