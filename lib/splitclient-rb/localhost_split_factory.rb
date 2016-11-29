require 'logger'
module SplitIoClient
  module SplitIoClient::FeatureUtils
    #
    # method to set localhost mode features by reading the given .splits
    #
    # @param splits_file [File] the .split file that contains the splits
    # @param reload_rate [Integer] the number of seconds to reload splits_file
    # @return nil
    def load_localhost_mode_features(splits_file, reload_rate = nil)
      return @localhost_mode_features unless File.exists?(splits_file)

      store_features(splits_file)

      return unless reload_rate

      Thread.new do
        loop do
          @localhost_mode_features = []
          store_features(splits_file)

          sleep(::Utilities.randomize_interval(reload_rate))
        end
      end
    end

    def store_features(splits_file)
      File.open(splits_file).each do |line|
        feature, treatment = line.strip.split(' ')

        next if line.start_with?('#') || line.strip.empty?

        @localhost_mode_features << { feature: feature, treatment: treatment }
      end
    end
  end

  #
  # main class for localhost split client sdk
  #
  class LocalhostSplitFactory < NoMethodError
    class LocalhostSplitManager < NoMethodError
      include SplitIoClient::FeatureUtils

      #
      # Creates a new split manager instance that holds the splits from a given file
      #
      # @param splits_file [File] the .split file that contains the splits
      # @param reload_rate [Integer] the number of seconds to reload splits_file
      #
      # @return [LocalhostSplitIoManager] split.io localhost manager instance
      def initialize(splits_file, reload_rate = nil)
        @localhost_mode = true
        @localhost_mode_features = []

        load_localhost_mode_features(splits_file, reload_rate)
      end

      #
      # method to get a split view
      #
      # @returns a split view
      def split(split_name)
        @localhost_mode_features.find { |x| x[:feature] == split_name }
      end

      #
      # method to get the split list from the client
      #
      # @returns [object] array of splits
      def splits
        @localhost_mode_features
      end

      #
      # method to get the list of just split names. Ideal for ietrating and calling client.get_treatment
      #
      # @returns [object] array of split names (String)
      def split_names
        @localhost_mode_features.each_with_object([]) do |split, memo|
          memo << split[:feature]
        end
      end
    end

    class LocalhostSplitClient < NoMethodError
      include SplitIoClient::FeatureUtils

      #
      # variables to if the sdk is being used in localhost mode and store the list of features
      attr_reader :localhost_mode
      attr_reader :localhost_mode_features

      #
      # Creates a new split client instance that reads from the given splits file
      #
      # @param splits_file [File] file that contains some splits
      #
      # @return [LocalhostSplitIoClient] split.io localhost client instance
      def initialize(splits_file, reload_rate = nil)
        @localhost_mode = true
        @localhost_mode_features = []
        load_localhost_mode_features(splits_file, reload_rate)
      end

      #
      # method that returns the sdk gem version
      #
      # @return [string] version value for this sdk
      def self.sdk_version
        'RubyClientSDK-'+SplitIoClient::VERSION
      end

      def get_treatments(key, split_names, attributes = nil)
        split_names.each_with_object({}) do |name, memo|
          puts "name #{name} memo #{memo}"
          memo.merge!(name => get_treatment(key, name, attributes))
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

        result = get_localhost_treatment(feature)
      end

      private

      #
      # auxiliary method to get the treatments avoding exceptions
      #
      # @param id [string] user id
      # @param feature [string] name of the feature that is being validated
      #
      # @return [Treatment]  tretment constant value
      def get_treatment_without_exception_handling(id, feature, attributes = nil)
        get_treatment(id, feature, attributes)
      end

      #
      # method to check if the sdk is running in localhost mode based on api key
      #
      # @return [boolean] True if is in localhost mode, false otherwise
      def is_localhost_mode?
        true
      end

      #
      # method to check the treatment for the given feature in localhost mode
      #
      # @return [boolean] true if the feature is available in localhost mode, false otherwise
      def get_localhost_treatment(feature)
        treatment = @localhost_mode_features.select { |h| h[:feature] == feature }.last || {}

        treatment[:treatment] || Treatments::CONTROL
      end
    end

    def initialize(splits_file, reload_rate = nil)
      @splits_file = splits_file
      @reload_rate = reload_rate
    end

    def client
      @client ||= LocalhostSplitClient.new(@splits_file, @reload_rate)
    end

    def manager
      @manager ||= LocalhostSplitManager.new(@splits_file, @reload_rate)
    end
  end
end
