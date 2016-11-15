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

          build_split_view(split_name, split) unless split.nil? or split_model(split).archived?
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
      def initialize(api_key, config = {}, adapter = nil, localhost_mode = false, splits_repository, segments_repository, impressions_repository, metrics_repository)
        @localhost_mode = localhost_mode
        @localhost_mode_features = []

        @config = config

        @splits_repository = splits_repository
        @segments_repository = segments_repository
        @impressions_repository = impressions_repository
        @metrics_repository = metrics_repository

        if api_key == LOCALHOST_MODE
          @localhost_mode = true
          load_localhost_mode_features
        else
          @adapter = adapter
        end
      end

      def get_treatments(key, split_names, attributes = nil)
        # This localhost behavior must live in in localhost_spit_factory#client
        if is_localhost_mode?
          return split_names.each_with_object({}) do |name, memo|
            memo.merge!(name => get_localhost_treatment(name))
          end
        end

        bucketing_key, matching_key = keys_from_key(key)
        bucketing_key = matching_key if bucketing_key.nil?

        treatments = @splits_repository.get_splits(split_names).each_with_object({}) do |(name, data), memo|
          memo.merge!(name => get_treatment(matching_key, name, attributes, data, false))
        end

        if @config.impressions_queue_size > 0
          @impressions_repository.add_bulk(matching_key, treatments, (Time.now.to_f * 1000.0).to_i)
        end

        treatments
      end

      #
      # obtains the treatment for a given feature
      #
      # @param key [String/Hash] user id or hash with matching_key/bucketing_key
      # @param split_name [String/Array] name of the feature that is being validated or array of them
      #
      # @return [String/Hash] Treatment as String or Hash of treatments in case of array of features
      def get_treatment(key, split_name, attributes = nil, split_data = nil, store_impressions = true)
        bucketing_key, matching_key = keys_from_key(key)
        bucketing_key = matching_key if bucketing_key.nil?

        if matching_key.nil?
          @config.logger.warn('matching_key was null for split_name: ' + split_name.to_s)
          return Treatments::CONTROL
        end

        if split_name.nil?
          @config.logger.warn('split_name was null for key: ' + key)
          return Treatments::CONTROL
        end

        if is_localhost_mode?
          result = get_localhost_treatment(split_name)
        else
          start = Time.now
          result = nil

          begin
            split = split_data ? split_data : @splits_repository.get_split(split_name)

            result = if split.nil?
              Treatments::CONTROL
            else
              SplitIoClient::Engine::Parser::SplitTreatment.new(@segments_repository).call(
                { bucketing_key: bucketing_key, matching_key: matching_key }, split, attributes
              )
            end
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end

          result = result.nil? ? Treatments::CONTROL : result

          begin
            latency = (Time.now - start) * 1000.0
            if @config.impressions_queue_size > 0 && store_impressions
              # Disable impressions if @config.impressions_queue_size == -1
              @impressions_repository.add(split_name, 'key_name' => matching_key, 'treatment' => result, 'time' => (Time.now.to_f * 1000.0).to_i)
            end

            # Measure
            @adapter.metrics.time("sdk.get_treatment", latency)
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
      # method that returns the sdk gem version
      #
      # @return [string] version value for this sdk
      def self.sdk_version
        'ruby-'+SplitIoClient::VERSION
      end

      private

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
    end

    private_constant :SplitClient
    private_constant :SplitManager

    def initialize(api_key, config = {})
      @api_key = api_key
      @config = SplitConfig.new(config)
      @cache_adapter = @config.cache_adapter
      @splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(@cache_adapter)
      @segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(@cache_adapter)
      @impressions_repository = SplitIoClient::Cache::Repositories::ImpressionsRepository.new(@config.impressions_adapter, @config)
      @metrics_repository = SplitIoClient::Cache::Repositories::MetricsRepository.new(@config.metrics_adapter, @config)
      @sdk_blocker = SplitIoClient::Cache::Stores::SDKBlocker.new(@config)
      @adapter = api_key != 'localhost' \
      ? SplitAdapter.new(api_key, @config, @splits_repository, @segments_repository, @impressions_repository, @metrics_repository, @sdk_blocker)
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
      SplitClient.new(@api_key, @config, @adapter, @localhost_mode, @splits_repository, @segments_repository, @impressions_repository, @metrics_repository)
    end

    def init_manager
      SplitManager.new(@api_key, @config, @adapter, @splits_repository, @localhost_mode)
    end
  end
end
