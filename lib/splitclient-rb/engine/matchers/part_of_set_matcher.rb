# frozen_string_literal: true

module SplitIoClient
  class PartOfSetMatcher < SetMatcher
    MATCHER_TYPE = 'PART_OF_SET'

    attr_reader :attribute

    def initialize(attribute, remote_array, logger)
      super(attribute, remote_array, logger)
    end

    def match?(args)
      @local_set = local_set(args[:attributes], @attribute)

      if @local_set.empty?
        @logger.log_if_debug('[PartOfSetMatcher] Local Set is empty.')
        return false
      end

      matches = @local_set.subset? @remote_set
      @logger.log_if_debug("[PartOfSetMatcher] Local Set #{@local_set} is a subset of #{@remote_set} -> #{matches}")
      matches
    end
  end
end
