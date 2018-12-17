require 'net/http/persistent'

module SplitIoClient
  module Api
    class Client
      RUBY_ENCODING = '1.9'.respond_to?(:force_encoding)

      def get_api(url, api_key, params = {})
        api_client.get(url, params) do |req|
          req.headers = common_headers(api_key).merge('Accept-Encoding' => 'gzip')

          req.options[:timeout] = SplitIoClient.configuration.read_timeout
          req.options[:open_timeout] = SplitIoClient.configuration.connection_timeout

          SplitIoClient.configuration.logger.debug("GET #{url} proxy: #{api_client.proxy}") if SplitIoClient.configuration.debug_enabled
        end
      rescue StandardError => e
        SplitIoClient.configuration.logger.warn("#{e}\nURL:#{url}\nparams:#{params}")
        raise 'Split SDK failed to connect to backend to retrieve information'
      end

      def post_api(url, api_key, data, headers = {}, params = {})
        api_client.post(url) do |req|
          req.headers = common_headers(api_key)
            .merge('Content-Type' => 'application/json')
            .merge(headers)

          req.body = data.to_json

          req.options[:timeout] = SplitIoClient.configuration.read_timeout
          req.options[:open_timeout] = SplitIoClient.configuration.connection_timeout

          if SplitIoClient.configuration.transport_debug_enabled
            SplitIoClient.configuration.logger.debug("POST #{url} #{req.body}")
          elsif SplitIoClient.configuration.debug_enabled
            SplitIoClient.configuration.logger.debug("POST #{url}")
          end
        end
      rescue StandardError => e
        SplitIoClient.configuration.logger.warn("#{e}\nURL:#{url}\ndata:#{data}\nparams:#{params}")
        raise 'Split SDK failed to connect to backend to retrieve information'
      end

      private

      def api_client
        @api_client ||= Faraday.new do |builder|
          builder.use SplitIoClient::FaradayMiddleware::Gzip
          builder.adapter :net_http_persistent
        end
      end

      def common_headers(api_key)
        {
          'Authorization' => "Bearer #{api_key}",
          'SplitSDKVersion' => "#{SplitIoClient.configuration.language}-#{SplitIoClient.configuration.version}",
          'SplitSDKMachineName' => SplitIoClient.configuration.machine_name,
          'SplitSDKMachineIP' => SplitIoClient.configuration.machine_ip,
          'Referer' => referer
        }
      end

      def referer
        result = "#{SplitIoClient.configuration.language}-#{SplitIoClient.configuration.version}"

        result = "#{result}::#{SplitIoClient::SplitConfig.machine_hostname}" unless SplitIoClient::SplitConfig.machine_hostname == 'localhost'

        result
      end
    end
  end
end
