require "json"
require "thread"
require "faraday/http_cache"

module SplitClient


  class SplitIoClient < NoMethodError

    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key)

      @api_key = api_key

      @api_client = Faraday.new do |builder|
        builder.use Faraday::HttpCache, store: SplitIoClient.local_store
        builder.adapter :net_http_persistent
      end

    end

    # validates if a features should be on or off for the given user id
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [boolean]  true if feature is on, false otherwise
    def is_on?(id, feature)
      result = false
      begin
        treatment = get_treatment(id, feature)
        result = !Treatments.is_control?(treatment)
        return result
      rescue
        #TODO: Log error, do not throw exception
      end
      result
    end

    # obtains the treatemen for a given feature
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [Treatment]  tretment constant value
    def get_treatment(id, feature)
      if id.nil?
        #TODO : log warn for null user id
        return Treatments::CONTROL
      end

      if feature.nil?
        return Treatments::CONTROL
      end

      begin
        treatment = get_treatment_without_exception_handling(id, feature)
        return treatment.nil? ? Treatments::CONTROL : treatment
      rescue
        #TODO : log error, do no throw exception
      end

      return Treatments::CONTROL
    end

    def get_treatment_without_exception_handling(id, feature)
      #TODO : complete method
      Treatments::CONTROL
    end

    def get_experiment_treatment(id, experiment)
      return Treatments::CONTROL
    end

    def call_api(path)
      @api_client.get (SplitIoClient.base_api_uri + path) do |req|
        req.headers["Authorization"] = "Bearer " + @api_key
        req.options.open_timeout = SplitIoClient.connection_timeout
        req.options.timeout = SplitIoClient.timeout
      end
    end

    def get_splits
      splits = make_request "/api/splitChanges"

      if res.status / 100 == 2
        return JSON.parse(splits.body, symbolize_names: true)[:items]
      else
        #TODO: log errors
        #Unexpected result from api call
      end
    end

    def process(str)
      Treatments::CONTROL
      str = str.downcase
      str
    end


    #self class methods for client configuration

    # @return [int] configuration value for timeout
    def self.timeout
      10
    end

    # @return [int] configuration value for connetion timeout
    def connection_timeout
      5
    end

    # @return [string] configuration value for api uri
    def self.base_api_uri
      #"https://sdk.split.io/api/"
      "http://localhost:8081/api/"
    end

    # @return [LocalStore] configuration value for local cache store
    def self.local_store
      defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : LocalStore.new
    end

    private :get_treatment_without_exception_handling, :get_experiment_treatment

  end

end
