# frozen_string_literal: true

module SplitIoClient
  module Api
    class Client
      def initialize(config)
        @config = config

        check_faraday_compatibility
      end

      def get_api(url, api_key, params = {}, cache_control_headers = false)
        api_client.options.params_encoder.sort_params = false
        api_client.get(url, params) do |req|
          req.headers = common_headers(api_key).merge('Accept-Encoding' => 'gzip')
          req.headers = req.headers.merge('Cache-Control' => 'no-cache') if cache_control_headers

          req.options[:timeout] = @config.read_timeout
          req.options[:open_timeout] = @config.connection_timeout

          @config.split_logger.log_if_debug("GET #{url} proxy: #{api_client.proxy}")
        end
      rescue StandardError => e
        @config.logger.warn("#{e}\nURL:#{url}\nparams:#{params}")
        raise e, 'Split SDK failed to connect to backend to retrieve information', e.backtrace
      end

      def post_api(url, api_key, data, headers = {}, params = {})
        api_client.post(url) do |req|
          req.headers = common_headers(api_key)
                        .merge('Content-Type' => 'application/json')
                        .merge(headers)

          machine_ip = @config.machine_ip
          machine_name = @config.machine_name

          req.headers = req.headers.merge('SplitSDKMachineIP' => machine_ip) unless machine_ip.empty? || machine_ip == 'unknown'
          req.headers = req.headers.merge('SplitSDKMachineName' => machine_name) unless machine_name.empty? || machine_name == 'unknown'

          req.body = data.to_json

          req.options[:timeout] = @config.read_timeout
          req.options[:open_timeout] = @config.connection_timeout

          @config.split_logger.log_if_transport("POST #{url} #{req.body}")
          @config.split_logger.log_if_debug("POST #{url}")
        end
      rescue StandardError => e
        @config.logger.warn("#{e}\nURL:#{url}\ndata:#{data}\nparams:#{params}")
        raise e, 'Split SDK failed to connect to backend to post information', e.backtrace
      end

      private

      def api_client
        @api_client ||= Faraday.new do |builder|
          builder.use SplitIoClient::FaradayMiddleware::Gzip
          builder.adapter :net_http_persistent
          builder.options.params_encoder = Faraday::FlatParamsEncoder
        end
      end

      def common_headers(api_key)
        {
          'Authorization' => "Bearer #{api_key}",
          'SplitSDKVersion' => "#{@config.language}-#{@config.version}",
        }
      end

      def check_faraday_compatibility
        version = Faraday::VERSION.split('.')[0]

        require 'faraday/net_http_persistent' if version.to_i >= 2
      rescue StandardError => e
        @config.logger.warn(e)
      end
    end
  end
end
