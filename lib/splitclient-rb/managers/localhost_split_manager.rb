module SplitIoClient
  class LocalhostSplitManager
    include SplitIoClient::LocalhostUtils

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
      features = @localhost_mode_features.find_all { |feat| feat[:feature] == split_name }

      return nil if features.nil?

      treatments = features.map { |feat| feat[:treatment] }

      configs = Hash[ features.map { |feat| [ feat[:treatment].to_sym, feat[:config] ] } ]

      {
        change_number: nil,
        killed:       false,
        name:         split_name,
        traffic_type:  nil,
        treatments:   treatments,
        configs: configs
      }
    end

    #
    # method to get the split list from the client
    #
    # @returns Array of split view
    def splits
      split_names.map do |split_name|
        split(split_name)
      end
    end

    #
    # method to get the list of just split names. Ideal for ietrating and calling client.get_treatment
    #
    # @returns [object] array of split names (String)
    def split_names
      @localhost_mode_features.map{ |feat| feat[:feature]}.uniq
    end
  end
end
