# frozen_string_literal: true

require 'net/http/persistent'

module SplitIoClient
  module Api
    class Client
      RUBY_ENCODING = '1.9'.respond_to?(:force_encoding)

      def initialize(config)
        @config = config
      end

      def get_api(url, api_key, params = {})
        api_client.get(url, params) do |req|
          req.headers = common_headers(api_key).merge('Accept-Encoding' => 'gzip')

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
                        
          req.headers = req.headers.merge('SplitSDKMachineIP' => @config.machine_ip) unless @config.machine_ip.empty?
          req.headers = req.headers.merge('SplitSDKMachineName' => @config.machine_name) unless @config.machine_name.empty?

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
        if needs_patched_net_http_persistent_adapter?
          require 'splitclient-rb/engine/api/faraday_adapter/patched_net_http_persistent'

          Faraday::Adapter.register_middleware(
            net_http_persistent: SplitIoClient::FaradayAdapter::PatchedNetHttpPersistent
          )
        end

        @api_client ||= Faraday.new do |builder|
          builder.use SplitIoClient::FaradayMiddleware::Gzip
          builder.adapter :net_http_persistent
        end
      end

      def needs_patched_net_http_persistent_adapter?
        new_net_http_persistent? && incompatible_faraday_version?
      end

      def incompatible_faraday_version?
        version = Faraday::VERSION.split('.')[0..1]
        version[0].to_i == 0 && version[1].to_i < 13
      end

      def new_net_http_persistent?
        Net::HTTP::Persistent::VERSION.split('.').first.to_i >= 3
      end

      def common_headers(api_key)
        {
          'Authorization' => "Bearer #{api_key}",
          'SplitSDKVersion' => "#{@config.language}-#{@config.version}",
        }
      end
    end
  end
end
