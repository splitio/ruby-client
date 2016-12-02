module SplitIoClient
  class LocalhostSplitManager
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
end
