require 'logger'
module SplitIoClient

  #
  # main class for localhost split client sdk
  #
  class LocalhostSplitFactory < NoMethodError
    class LocalhostSplitManager < NoMethodError
      #
      # constant that defines the localhost mode
      LOCALHOST_MODE = 'localhost'

      #
      # object that acts as an api adapter connector. used to get and post to api endpoints
      attr_reader :adapter

      #
      # Creates a new split manager instance that holds the splits from a given file
      #
      # @param splits_file [File] the .split file that contains the splits
      #
      # @return [LocalhostSplitIoManager] split.io localhost manager instance
      def initialize(splits_file)
        @localhost_mode = true
        @localhost_mode_features = []
        load_localhost_mode_features(splits_file)
      end

      #
      # method to set localhost mode features by reading the given .splits
      #
      # @param splits_file [File] the .split file that contains the splits
      # @returns [void]
      def load_localhost_mode_features(splits_file)
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
        @localhost_mode_features
      end
    end

    class LocalhostSplitClient < NoMethodError
      #
      # constant that defines the localhost mode
      LOCALHOST_MODE = 'localhost'

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
      def initialize(splits_file)
        @localhost_mode = true
        @localhost_mode_features = []
        load_localhost_mode_features(splits_file)
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
        true
      end

      #
      # method to set localhost mode features by reading .splits file located at home directory
      #
      # @returns [void]
      def load_localhost_mode_features(splits_file)
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

    private_constant :LocalhostSplitClient
    private_constant :LocalhostSplitManager

    def initialize(splits_file)
      @splits_file = splits_file
    end

    def client
      @client ||= LocalhostSplitClient.new(@splits_file)
    end

    def manager
      @manager ||= LocalhostSplitManager.new(@splits_file)
    end
  end
end
