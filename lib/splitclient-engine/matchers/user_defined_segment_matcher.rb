module SplitIoClient

  #
  # class to implement the user defined matcher
  #
  class UserDefinedSegmentMatcher < NoMethodError

    @segment = nil

    def initialize(segment)
      unless segment.nil?
        @segment = segment
      end
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the key against the segment
    def match?(key)
      matches = false
      unless @segment.users.nil?
        matches = @segment.users.include?(key)
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

    #
    # function to print string value for this matcher
    #
    # @reutrn [string] string value of this matcher
    def to_s
      'in segment ' + @segment.name
    end

  end

end