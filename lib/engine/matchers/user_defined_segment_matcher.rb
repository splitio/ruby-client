module SplitIoClient

  #
  # class to implement the user defined matcher
  #
  class UserDefinedSegmentMatcher < NoMethodError

    attr_reader :matcher_type

    def initialize(segments_repository, segment_name)
      @matcher_type = "IN_SEGMENT"
      @segments_repository = segments_repository
      @segment_name = segment_name
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the key against the segment
    def match?(key, attributes)
      @segments_repository.in_segment?(@segment_name, key)
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

    def to_s
      "in segment #{@segment_name}"
    end
  end
end
