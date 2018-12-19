module SplitIoClient
  #
  # class to implement the user defined matcher
  #
  class UserDefinedSegmentMatcher
    MATCHER_TYPE = 'IN_SEGMENT'.freeze

    def initialize(segments_repository, segment_name)
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
      SplitLogger.log_if_debug("[InSegmentMatcher] #{@segment_name} is in segment -> #{matches}");
      matches
    end

    #
    # evaluates if the given object equals the matcher
    #
    # @param obj [object] object to be evaluated
    #
    # @returns [boolean] true if obj equals the matcher
    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(UserDefinedSegmentMatcher)
        false
      elsif self.equal?(obj)
        true
      else
        false
      end
    end

    def string_type?
      false
    end
  end
end
