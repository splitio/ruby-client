require 'logger'

module SplitIoClient

  class SplitClient < NoMethodError
    attr_reader :adapter
    attr_reader :pusher
    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config = SplitConfig.default)

      #@adapter = SplitAdapter.new(api_key, config)
      @adapter = SplitAdapter.new('ictlpssmv2rqhqb6b59fumq9lj', config)
      @config = config

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

    def get_treatment_without_exception_handling(id, feature)
      @adapter.parsed_splits.segments = @adapter.parsed_segments
      split = @adapter.parsed_splits.get_split(feature)

      if split.nil?
        return Treatments::CONTROL
      else
        return @adapter.parsed_splits.get_split_treatment(id, feature)
      end
    end

    def self.sdk_version
      'RubyClientSDK-'+SplitIoClient::VERSION
    end

    #def test()
    #  @adapter.get_segments(@adapter.parsed_splits.get_used_segments)
    #end

    private :get_treatment_without_exception_handling

  end

end
