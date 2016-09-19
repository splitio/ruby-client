module SplitIoClient

  #
  # class to implement the user defined matcher
  #
  class UserDefinedSegmentMatcher < NoMethodError

    attr_reader :matcher_type

    def initialize(segment_keys)
      @matcher_type = "IN_SEGMENT"
      @segment_keys = segment_keys
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the key against the segment
    def match?(key, attributes)
      matches = false
      unless @segment_keys.nil?
        matches = @segment_keys.include?(key)
      end
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
  end
end
