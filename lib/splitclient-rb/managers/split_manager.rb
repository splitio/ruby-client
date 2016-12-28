module SplitIoClient
  class SplitManager
    #
    # Creates a new split manager instance that connects to split.io API.
    #
    # @param api_key [String] the API key for your split account
    #
    # @return [SplitIoManager] split.io client instance
    def initialize(api_key, config = {}, adapter = nil, splits_repository = nil)
      @localhost_mode_features = []
      @config = config
      @splits_repository = splits_repository
      @adapter = adapter
    end

    #
    # method to get the split list from the client
    #
    # @returns [object] array of splits
    def splits
      return if @splits_repository.nil?

      @splits_repository.splits.each_with_object([]) do |(name, split), memo|
        split_model = Engine::Models::Split.new(split)
        split_view = build_split_view(name, split)

        next if split_view[:name] == nil

        memo << split_view unless split_model.archived?
      end
    end

    #
    # method to get the list of just split names. Ideal for ietrating and calling client.get_treatment
    #
    # @returns [object] array of split names (String)
    def split_names
      return if @splits_repository.nil?

      @splits_repository.split_names
    end

    #
    # method to get a split view
    #
    # @returns a split view
    def split(split_name)
      if @splits_repository
        split = @splits_repository.get_split(split_name)

        build_split_view(split_name, split) unless split.nil? or split_model(split).archived?
      end
    end

    def build_split_view(name, split)
      return {} unless split

      treatments =
        if split[:conditions] && split[:conditions][0][:partitions]
          split[:conditions][0][:partitions].map { |partition| partition[:treatment] }
        else
          []
        end

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
end
