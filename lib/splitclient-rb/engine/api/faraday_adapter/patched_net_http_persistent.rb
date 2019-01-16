# frozen_string_literal: true

module SplitIoClient
  module FaradayAdapter
    class PatchedNetHttpPersistent < Faraday::Adapter::NetHttpPersistent
      ##
      # Borrowed directly from the latest `NetHttpPersistent` adapter implementation.
      #
      # https://github.com/lostisland/faraday/blob/master/lib/faraday/adapter/net_http_persistent.rb
      #
      def net_http_connection(env)
        @cached_connection ||=
          if Net::HTTP::Persistent.instance_method(:initialize).parameters.first == [:key, :name]
            Net::HTTP::Persistent.new(name: 'Faraday')
          else
            Net::HTTP::Persistent.new('Faraday')
          end

        proxy_uri                = proxy_uri(env)
        @cached_connection.proxy = proxy_uri if @cached_connection.proxy_uri != proxy_uri
        @cached_connection
      end

      def proxy_uri(env)
        proxy_uri = nil
        if (proxy = env[:request][:proxy])
          proxy_uri      = ::URI::HTTP === proxy[:uri] ? proxy[:uri].dup : ::URI.parse(proxy[:uri].to_s)
          proxy_uri.user = proxy_uri.password = nil
          # awful patch for net-http-persistent 2.8 not unescaping user/password
          (
          class << proxy_uri;
            self;
          end).class_eval do
            define_method(:user) { proxy[:user] }
            define_method(:password) { proxy[:password] }
          end if proxy[:user]
        end
        proxy_uri
      end

      def with_net_http_connection(env)
        yield net_http_connection(env)
      end
    end
  end
end