require "json"
require "thread"
require "faraday/http_cache"
require "bundler/vendor/net/http/persistent"


module SplitIoClient

  class SplitFetcher < NoMethodError

    # Creates a new split fetcher instance that consumes to split.io APIs
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key)

      @api_key = api_key

      @api_client = Faraday.new do |builder|
        builder.use Faraday::HttpCache, store: SplitFetcher.local_store
        builder.adapter :net_http_persistent
      end

      @consumer = create_api_consumer
    end

    def create_api_consumer
      Thread.new do
        loop do
          begin
            splits = get_splits
            sleep(SplitFetcher.exec_interval)
          rescue StandardError => exn
            #TODO log error for the time being send msg to def output
            puts exn.to_s
          end
        end
      end
    end

    def call_api(path)
      @api_client.get (SplitFetcher.base_api_uri + path) do |req|
        req.headers["Authorization"] = "Bearer " + @api_key
        req.options.open_timeout = SplitFetcher.connection_timeout
        req.options.timeout = SplitFetcher.timeout
      end
    end

    def get_splits
      splits = call_api("/splitChanges")

      if splits.status / 100 == 2
        puts 'hola'
        puts splits.body
        return JSON.parse(splits.body, symbolize_names: true)[:items]
      else
        #TODO: log errors
        #Unexpected result from api call
      end
    end

    def get_segments
      segments = call_api("/segmentChanges")

      if segments.status / 100 == 2
        return JSON.parse(segments.body, symbolize_names: true)[:items]
      else
        #TODO: log errors
        #Unexpected result from api call
      end
    end

    #self class methods for client configuration

    # @return [int] configuration value for timeout
    def self.timeout
      10
    end

    # @return [int] configuration value for connetion timeout
    def self.connection_timeout
      5
    end

    # @return [string] configuration value for api uri
    def self.base_api_uri
      #"https://sdk.split.io/api/"
      "http://localhost:8081/api"
    end

    # @return [LocalStore] configuration value for local cache store
    def self.local_store
      defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : LocalStore.new
    end

    # @return [int] configuration value for execution interval
    def self.exec_interval
      #5.minutes
      10
    end

  end
end