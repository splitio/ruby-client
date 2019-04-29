# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the user defined matcher
  #
  class UserDefinedSegmentMatcher < Matcher
    MATCHER_TYPE = 'IN_SEGMENT'

    def initialize(segments_repository, segment_name, config)
      super(config)
      @segments_repository = segments_repository
      @segment_name = segment_name
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the key against the segment
    def match?(args)
      matches = @segments_repository.in_segment?(@segment_name, args[:value] || args[:matching_key])
      @config.log_if_debug("[InSegmentMatcher] #{@segment_name} is in segment -> #{matches}")
      matches
    end
  end
end
