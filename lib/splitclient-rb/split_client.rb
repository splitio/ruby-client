require 'logger'

module SplitIoClient

  #
  # main class for split client sdk
  #
  class SplitClient < NoMethodError

    #
    # constant that defines the localhost mode
    LOCALHOST_MODE = 'localhost'

    #
    # object that acts as an api adapter connector. used to get and post to api endpoints
    attr_reader :adapter

    #
    # variables to if the sdk is being used in localhost mode and store the list of features
    attr_reader :localhost_mode
    attr_reader :localhost_mode_features

    #
    # Creates a new split client instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoClient] split.io client instance
    def initialize(api_key, config = {})
      @localhost_mode = false
      @localhost_mode_features = []

      @config = SplitConfig.new(config)

      if api_key == LOCALHOST_MODE
        @localhost_mode = true
        load_localhost_mode_features
      else
        @adapter = SplitAdapter.new(api_key, @config)
      end
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

      if is_localhost_mode?
        result = get_localhost_treatment(feature)
      else
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

    #
    # method to check if the sdk is running in localhost mode based on api key
    #
    # @return [boolean] True if is in localhost mode, false otherwise
    def is_localhost_mode?
      @localhost_mode
    end

    #
    # method to set localhost mode features by reading .splits file located at home directory
    #
    # @returns [void]
    def load_localhost_mode_features
      splits_file = File.join(Dir.home, ".splits")
      if File.exists?(splits_file)
        line_num=0
        File.open(splits_file).each do |line|
          @localhost_mode_features << line.strip unless line.start_with?('#') || line.strip.empty?
        end
      end
    end

    #
    # method to check the treatment for the given feature in localhost mode
    #
    # @return [boolean] true if the feature is available in localhost mode, false otherwise
    def get_localhost_treatment(feature)
      @localhost_mode_features.include?(feature)
    end

    private :get_treatment_without_exception_handling, :is_localhost_mode?, :load_localhost_mode_features,
            :get_localhost_treatment

  end

end
