require 'logger'
module SplitIoClient
  #
  # main class for split client sdk
  #
  class SplitFactory < NoMethodError
    class SplitManager < NoMethodError
      #
      # constant that defines the localhost mode
      LOCALHOST_MODE = 'localhost'

      #
      # Creates a new split manager instance that connects to split.io API.
      #
      # @param api_key [String] the API key for your split account
      #
      # @return [SplitIoManager] split.io client instance
      def initialize(api_key, config = {}, adapter = nil, localhost_mode = false)
        @localhost_mode_features = []
        @config = config
        @localhost_mode = localhost_mode
        if @localhost_mode
          load_localhost_mode_features
        else
          @adapter = adapter
        end
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
      # method to get the split list from the client
      #
      # @returns [object] array of splits
      def splits
        if @adapter
          @adapter.parsed_splits.splits.map do |split|
            {
              name: split[:name],
              traffic_type_name: split[:traffiTypeName],
              killed: split[:killed],
              treatments: split[:partitions],
              change_number: split[:changeNumber]
            }
          end
        else
          @localhost_mode_features
        end
      end
    end

    class SplitClient < NoMethodError
      #
      # constant that defines the localhost mode
      LOCALHOST_MODE = 'localhost'

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
      def initialize(api_key, config = {}, adapter = nil)
        @localhost_mode = false
        @localhost_mode_features = []

        @config = config

        if api_key == LOCALHOST_MODE
          @localhost_mode = true
          load_localhost_mode_features
        else
          @adapter = adapter
        end
      end

      #
      # obtains the treatment for a given feature
      #
      # @param id [string] user id
      # @param feature [string] name of the feature that is being validated
      #
      # @return [Treatment]  treatment constant value
      def get_treatment(id, feature, attributes = nil)
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
            result = get_treatment_without_exception_handling(id, feature, attributes)
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
      def get_treatment_without_exception_handling(id, feature, attributes = nil)
        @adapter.parsed_splits.segments = @adapter.parsed_segments
        split = @adapter.parsed_splits.get_split(feature)

        if split.nil?
          return Treatments::CONTROL
        else
          default_treatment = split.data[:defaultTreatment]
          return @adapter.parsed_splits.get_split_treatment(id, feature, default_treatment, attributes)
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

    private_constant :SplitClient
    private_constant :SplitManager

    def initialize(api_key, config = {})
      @api_key = api_key
      @config = SplitConfig.new(config)
      @adapter = api_key != 'localhost' \
      ? SplitAdapter.new(api_key, @config)
      : nil
    end

    def client
      @client ||= SplitClient.new(@api_key, @config, @adapter)
    end

    def manager
      @manager ||= SplitManager.new(@api_key, @config, @adapter)
    end

    private
      attr_reader :adapter
  end
end
