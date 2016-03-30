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
    # validates the treatment for the provided user key and feature
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    # @param treatment [string] value of the treatment for this user key and feature
    #
    # @return [boolean] true if the user key has valida treatment, false otherwise
    def is_treatment?(id, feature, treatment)
      is_treatment = false

      if is_localhost_mode?
        is_treatment = get_localhost_treatment(feature)
      else
        begin
          is_treatment = (get_treatment(id, feature) == treatment)
        rescue
          @config.logger.error("MUST NOT throw this error")
        end
      end
      is_treatment
    end

    #
    # obtains the treatment for a given feature
    #
    # @param id [string] user id
    # @param feature [string] name of the feature that is being validated
    #
    # @return [Treatment]  treatment constant value
    def get_treatment(id, feature)
      unless id
        @config.logger.warn('id was null for feature: ' + feature)
        return Treatments::CONTROL
      end

      unless feature
        @config.logger.warn('feature was null for id: ' + id)
        return Treatments::CONTROL
      end

      if is_localhost_mode?
        result = get_localhost_treatment(feature)
      else
        start = Time.now
        result = nil

        begin
          result = get_treatment_without_exception_handling(id, feature)
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

        result = result.nil? ? Treatments::CONTROL : result

        begin
          @adapter.impressions.log(id, feature, result, (Time.now.to_f * 1000.0))
          latency = (Time.now - start) * 1000.0
          if (@adapter.impressions.queue.length >= @adapter.impressions.max_number_of_keys)
            @adapter.impressions_producer.wakeup
          end
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
        end

      end

      result
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
        default_treatment = split.data[:defaultTreatment]
        return @adapter.parsed_splits.get_split_treatment(id, feature, default_treatment)
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
      splits_file = File.join(Dir.home, ".split")
      if File.exists?(splits_file)
        line_num=0
        File.open(splits_file).each do |line|
          line_data = line.strip.split(" ")
          @localhost_mode_features << {feature: line_data[0], treatment: line_data[1]} unless line.start_with?('#') || line.strip.empty?
        end
      end
    end

    #
    # method to check the treatment for the given feature in localhost mode
    #
    # @return [boolean] true if the feature is available in localhost mode, false otherwise
    def get_localhost_treatment(feature)
      localhost_result = Treatments::CONTROL
      treatment = @localhost_mode_features.select{|h| h[:feature] == feature}.last
      localhost_result = treatment[:treatment] if !treatment.nil?
      localhost_result
    end

    private :get_treatment_without_exception_handling, :is_localhost_mode?,
            :load_localhost_mode_features, :get_localhost_treatment

  end

end
