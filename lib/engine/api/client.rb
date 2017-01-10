require 'faraday/http_cache'
require 'bundler/vendor/net/http/persistent' unless defined?(Net::HTTP)
require 'faraday_middleware'

module SplitIoClient
  module Api
    class Client
      def get_api(url, config, api_key, params = {})
        api_client.get(url, params) do |req|
          req.headers = common_headers(api_key, config).merge('Accept-Encoding' => 'gzip')

          req.options.timeout = config.read_timeout
          req.options.open_timeout = config.connection_timeout

          config.logger.debug("GET #{url}") if config.debug_enabled
        end
      rescue StandardError => e
        config.logger.warn("#{e}\nURL:#{url}\nparams:#{params}")

        false
      end

      def post_api(url, config, api_key, data, headers = {}, params = {})
        api_client.post(url) do |req|
          req.headers = common_headers(api_key, config)
            .merge('Content-Type' => 'application/json')
            .merge(headers)

          req.body = data.to_json

          req.options.timeout = config.read_timeout
          req.options.open_timeout = config.connection_timeout

          if config.transport_debug_enabled
            config.logger.debug("POST #{url} #{req.body}")
          elsif config.debug_enabled
            config.logger.debug("POST #{url}")
          end
        end
      rescue StandardError => e
        config.logger.warn("#{e}\nURL:#{url}\ndata:#{data}\nparams:#{params}")

        false
      end

      private

      def api_client
        @api_client ||= Faraday.new do |builder|
          builder.use FaradayMiddleware::Gzip
          builder.adapter :net_http_persistent
        end
      end

      def common_headers(api_key, config)
        {
          'Authorization' => "Bearer #{api_key}",
          'SplitSDKVersion' => SplitIoClient::SplitConfig.sdk_version,
          'SplitSDKMachineName' => config.machine_name,
          'SplitSDKMachineIP' => config.machine_ip,
          'Referer' => referer
        }
      end

      def referer
        result = SplitIoClient::SplitConfig.sdk_version

        result = "#{result}::#{SplitIoClient::SplitConfig.get_hostname}" unless SplitIoClient::SplitConfig.get_hostname == 'localhost'

        result
      end
    end
  end
end
