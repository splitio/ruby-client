require 'logger'

module SplitIoClient

  #
  # main class for split client sdk
  #
  class SplitClient < NoMethodError
    #
    # object that acts as an api adapter connector. used to get and post to api endpoints
    attr_reader :adapter

    #
    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config = SplitConfig.default)

      @adapter = SplitAdapter.new(api_key, config)
      @config = config

    end

    #
    # validates if a features should be on or off for the given user id
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [boolean]  true if feature is on, false otherwise
    def is_on?(id, feature)
      result = false

      begin
        start = Time.now
        treatment = get_treatment(id, feature)
        result = Treatments.is_control?(treatment) ? false : true
        @adapter.impressions.log(id, feature, treatment, Time.now)
        latency = (Time.now - start) * 1000.0
        @adapter.metrics.time('sdk.is_on', latency)
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end
      result
    end

    #
    # obtains the treatment for a given feature
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [Treatment]  tretment constant value
    def get_treatment(id, feature)
      unless id
        @config.logger.error('user id must be provided')
        return Treatments::CONTROL
      end

      unless feature
        @config.logger.error('feature must be provided')
        return Treatments::CONTROL
      end

      begin
        treatment = get_treatment_without_exception_handling(id, feature)
        return treatment.nil? ? Treatments::CONTROL : treatment
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end
    end

    #
    # auxiliary method to get the treatments avoding exceptions
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [Treatment]  tretment constant value
    def get_treatment_without_exception_handling(id, feature)
      @adapter.parsed_splits.segments = @adapter.parsed_segments
      split = @adapter.parsed_splits.get_split(feature)

      if split.nil?
        return Treatments::CONTROL
      else
        return @adapter.parsed_splits.get_split_treatment(id, feature)
      end
    end

    #
    # method that returns the sdk gem version
    #
    # @return [string] version value for this sdk
    def self.sdk_version
      'RubyClientSDK-'+SplitIoClient::VERSION
    end

    private :get_treatment_without_exception_handling

  end

end
