module SplitIoClient
  module Api
    class Client
      def call_api(path, config, api_key, params = {})
        api_client.get(config.base_uri + path, params) do |req|
          req.headers['Authorization'] = 'Bearer ' + api_key
          req.headers['SplitSDKVersion'] = SplitIoClient::SplitFactory.sdk_version
          req.headers['SplitSDKMachineName'] = config.machine_name
          req.headers['SplitSDKMachineIP'] = config.machine_ip
          req.headers['Accept-Encoding'] = 'gzip'

          req.options.open_timeout = config.connection_timeout
          req.options.timeout = config.read_timeout

          config.logger.debug("GET #{config.base_uri + path}") if config.debug_enabled
        end
      end

      private

      def api_client
        @api_client ||= Faraday.new do |builder|
          builder.use FaradayMiddleware::Gzip
          builder.adapter :net_http_persistent
        end
      end
    end
  end
end
