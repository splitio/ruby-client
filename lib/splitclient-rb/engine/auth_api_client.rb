# frozen_string_literal: true

require 'jwt'
require 'cgi'

module SplitIoClient
  module Engine
    class AuthApiClient
      def initialize(config, telemetry_runtime_producer, request_decorator)
        @config = config
        @api_client = SplitIoClient::Api::Client.new(@config, request_decorator)
        @telemetry_runtime_producer = telemetry_runtime_producer
      end

      def authenticate(api_key)
        start = Time.now
        response = @api_client.get_api(@config.auth_service_url, api_key)

        return process_success(response, start) if response.success?

        return process_error(response) if response.status >= 400 && response.status < 500

        @telemetry_runtime_producer.record_sync_error(Telemetry::Domain::Constants::TOKEN_SYNC, response.status.to_i)
        @config.logger.debug("Error connecting to: #{@config.auth_service_url}. Response status: #{response.status}")
        { push_enabled: false, retry: true }
      rescue StandardError => e
        @config.logger.debug("AuthApiClient error: #{e.inspect}.")
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

      def process_error(response)
        @config.logger.debug("Error connecting to: #{@config.auth_service_url}. Response status: #{response.status}")
        @telemetry_runtime_producer.record_auth_rejections if response.status == 401

        { push_enabled: false, retry: false }
      end

      def process_success(response, start)
        @config.logger.debug("Success connection to: #{@config.auth_service_url}") if @config.debug_enabled
        record_telemetry(start)

        body_json = JSON.parse(response.body, symbolize_names: true)
        push_enabled = body_json[:pushEnabled]
        token = body_json[:token]

        if push_enabled
          decoded_token = decode_token(token)
          channels = channels(decoded_token)
          exp = expiration(decoded_token)

          @telemetry_runtime_producer.record_token_refreshes
        end

        { push_enabled: push_enabled, token: token, channels: channels, exp: exp, retry: true }
      end

      def control_channels(channels_string)
        prefix = SplitIoClient::Constants::OCCUPANCY_CHANNEL_PREFIX
        control_pri = SplitIoClient::Constants::CONTROL_PRI
        control_sec = SplitIoClient::Constants::CONTROL_SEC
        channels_string = channels_string.gsub(control_pri, "#{prefix}#{control_pri}")

        channels_string.gsub(control_sec, "#{prefix}#{control_sec}")
      end

      def record_telemetry(start)
        bucket = BinarySearchLatencyTracker.get_bucket((Time.now - start) * 1000.0)
        @telemetry_runtime_producer.record_sync_latency(Telemetry::Domain::Constants::TOKEN_SYNC, bucket)
        timestamp = (Time.now.to_f * 1000.0).to_i
        @telemetry_runtime_producer.record_successful_sync(Telemetry::Domain::Constants::TOKEN_SYNC, timestamp)
      end
    end
  end
end
