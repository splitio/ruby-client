module SplitIoClient
  class SplitManager
    #
    # Creates a new split manager instance that connects to split.io API.
    #
    # @return [SplitIoManager] split.io client instance
    def initialize(splits_repository = nil, status_manager, config)
      @splits_repository = splits_repository
      @status_manager = status_manager
      @config = config
    end

    #
    # method to get the split list from the client
    #
    # @returns [object] array of splits
    def splits
      return [] if !@config.valid_mode || @splits_repository.nil?

      if !ready?
        @config.logger.error("splits: the SDK is not ready, the operation cannot be executed")
        return []
      end

      @splits_repository.splits.each_with_object([]) do |(name, split), memo|
        split_view = build_split_view(name, split)

        next if split_view[:name] == nil

        memo << split_view unless Engine::Models::Split.archived?(split)
      end
    end

    #
    # method to get the list of just split names. Ideal for ietrating and calling client.get_treatment
    #
    # @returns [object] array of split names (String)
    def split_names
      return [] if !@config.valid_mode || @splits_repository.nil?

      if !ready?
        @config.logger.error("split_names: the SDK is not ready, the operation cannot be executed")
        return []
      end

      @splits_repository.split_names
    end

    #
    # method to get a split view
    #
    # @returns a split view
    def split(feature_flag_name)
      return unless @config.valid_mode && @splits_repository && @config.split_validator.valid_split_parameters(feature_flag_name)

      if !ready?
        @config.logger.error("split: the SDK is not ready, the operation cannot be executed")
        return
      end

      sanitized_feature_flag_name = feature_flag_name.to_s.strip

      if feature_flag_name.to_s != sanitized_feature_flag_name
        @config.logger.warn("split: feature_flag_name #{feature_flag_name} has extra whitespace, trimming")
        feature_flag_name = sanitized_feature_flag_name
      end

      split = @splits_repository.get_split(feature_flag_name)

      if ready? && split.nil?
        @config.logger.warn("split: you passed #{feature_flag_name} " \
          'that does not exist in this environment, please double check what feature flags exist in the Split user interface')
      end

      return if split.nil? || Engine::Models::Split.archived?(split)

      build_split_view(feature_flag_name, split)
    end

    def block_until_ready(time = nil)
      @status_manager.wait_until_ready(time) if @status_manager
    end

    private

    def build_split_view(name, split)
      return {} unless split

      begin
        if @config.localhost_mode
          treatments = split[:conditions]
            .first[:partitions]
            .map { |partition| partition[:treatment] }
        else
          treatments = split[:conditions]
            .detect { |c| c[:conditionType] == 'ROLLOUT' }[:partitions]
            .map { |partition| partition[:treatment] }
        end
      rescue StandardError
        treatments = []
      end
        {
          name: name,
          traffic_type_name: split[:trafficTypeName],
          killed: split[:killed],
          treatments: treatments,
          change_number: split[:changeNumber],
          configs: split[:configurations] || {},
          sets: split[:sets] || [],
          default_treatment: split[:defaultTreatment]
        }
    end

    # move to blocker, alongside block until ready to avoid duplication
    def ready?
      return @status_manager.ready? if @status_manager
      true
    end
  end
end
