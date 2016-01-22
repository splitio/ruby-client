module SplitIoClient

  class UserDefinedSegmentMatcher < NoMethodError

    @segment = nil

    def initialize(segment)
      if !segment.nil?
        @segment = segment
      end
    end

    def match?(key)
      @segment.added.include?(key)
    end

    def equals?(obj)
      if obj.nil?
        return false
      elsif !obj.instance_of?(UserDefinedSegmentMatcher)
        return false
      elsif self.equal?(obj)
        return true
      else
        return false
      end
    end

    def to_s
      "in segment " + @segment.name
    end

  end

end