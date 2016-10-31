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
      def initialize(api_key, config = {}, adapter = nil, splits_repository = nil, localhost_mode = false)
        @localhost_mode_features = []
        @config = config
        @splits_repository = splits_repository
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
        @localhost_mode_features
      end

      #
      # method to get the split list from the client
      #
      # @returns [object] array of splits
      def splits
        return @localhost_mode_features if @localhost_mode
        return if @splits_repository.nil?

        @splits_repository.splits.each_with_object([]) do |(name, split), memo|
          split_model = Engine::Models::Split.new(split)

          memo << build_split_view(name, split) unless split_model.archived?
        end
      end

      #
      # method to get the list of just split names. Ideal for ietrating and calling client.get_treatment
      #
      # @returns [object] array of split names (String)
      def split_names
        if @localhost_mode
          local_feature_names = []
          @localhost_mode_features.each do  |split|
            local_feature_names << split[:feature]
          end
          return local_feature_names
        end

        return if @splits_repository.nil?

        @splits_repository.split_names
      end

      #
      # method to get a split view
      #
      # @returns a split view
      def split(split_name)

        if @localhost_mode
          return @localhost_mode_features.find {|x| x[:feature] == split_name}
        end

        if @splits_repository
          split = @splits_repository.get_split(split_name)

          build_split_view(split_name, split) unless split_model(split).archived?
        end
      end

      def build_split_view(name, split)
        treatments = split[:conditions] && split[:conditions][0][:partitions] \
          ? split[:conditions][0][:partitions].map{ |partition| partition[:treatment] }
          : []
          {
            name: name,
            traffic_type_name: split[:trafficTypeName],
            killed: split[:killed],
            treatments: treatments,
            change_number: split[:changeNumber]
          }
      end

      private

      def split_model(split)
        split_model = Engine::Models::Split.new(split)
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
      def initialize(api_key, config = {}, adapter = nil, localhost_mode = false, splits_repository, segments_repository)
        @localhost_mode = localhost_mode
        @localhost_mode_features = []

        @config = config

        @splits_repository = splits_repository
        @segments_repository = segments_repository

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
      # @param key [string/hash] user id or hash with matching_key/bucketing_key
      # @param feature [string] name of the feature that is being validated
      #
      # @return [Treatment]  treatment constant value
      def get_treatment(key, feature, attributes = nil)
        bucketing_key, matching_key = keys_from_key(key)
        bucketing_key = matching_key if bucketing_key.nil?

        if matching_key.nil?
          @config.logger.warn('matching_key was null for feature: ' + feature)
          return Treatments::CONTROL
        end

        if feature.nil?
          @config.logger.warn('feature was null for key: ' + key)
          return Treatments::CONTROL
        end

        if is_localhost_mode?
          result = get_localhost_treatment(feature)
        else
          start = Time.now
          result = nil

          begin
            result = get_treatment_without_exception_handling({ bucketing_key: bucketing_key, matching_key: matching_key }, feature, attributes)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end

          result = result.nil? ? Treatments::CONTROL : result

          begin
            @adapter.impressions.log(matching_key, feature, result, (Time.now.to_f * 1000.0))
            latency = (Time.now - start) * 1000.0
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end

        end

        result
      end

      def keys_from_key(key)
        case key.class.to_s
        when 'Hash'
          key.values_at(:bucketing_key, :matching_key)
        when 'String'
          [key, key]
        end
      end

      #
      # auxiliary method to get the treatments avoding exceptions
      #
      # @param key [string/hash] user id or hash with matching_key/bucketing_key
      # @param feature [string] name of the feature that is being validated
      #
      # @return [Treatment]  tretment constant value
      def get_treatment_without_exception_handling(key, feature, attributes = nil)

        split = @splits_repository.get_split(feature)

        if split.nil?
          Treatments::CONTROL
        else
          default_treatment = split[:defaultTreatment]

          SplitIoClient::Engine::Parser::SplitTreatment
            .new(@segments_repository)
            .call(key, split, default_treatment, attributes)
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
      @cache_adapter = @config.cache_adapter
      @splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(@cache_adapter)
      @segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(@cache_adapter)
      @sdk_blocker = SplitIoClient::Cache::Stores::SDKBlocker.new(@config)
      @adapter = api_key != 'localhost' \
      ? SplitAdapter.new(api_key, @config, @splits_repository, @segments_repository, @sdk_blocker)
      : nil
      @localhost_mode = api_key == 'localhost'

      @sdk_blocker.block if @config.block_until_ready
    end

    def client
      @client ||= init_client
    end

    def manager
      @manager ||= init_manager
    end

    #
    # method that returns the sdk gem version
    #
    # @return [string] version value for this sdk
    def self.sdk_version
      'RubyClientSDK-'+SplitIoClient::VERSION
    end

    private
      attr_reader :adapter

    def init_client
      SplitClient.new(@api_key, @config, @adapter, @localhost_mode, @splits_repository, @segments_repository)
    end

    def init_manager
      SplitManager.new(@api_key, @config, @adapter, @splits_repository, @localhost_mode)
    end
  end
end
