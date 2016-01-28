module SplitIoClient

  class UserDefinedSegmentMatcher < NoMethodError

    @segment = nil

    def initialize(segment)
      unless segment.nil?
        @segment = segment
      end
    end

    def match?(key)
      matches = false
      unless @segment.users.nil?
        matches = @segment.users.include?(key)
      end
      matches
    end

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
      'in segment ' + @segment.name
    end

  end

end