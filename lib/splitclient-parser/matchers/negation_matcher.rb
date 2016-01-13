module SplitIoClient

  class NegationMatcher < NoMethodError

    @matcher = nil

    def initialize(matcher)
      if !matcher.nil?
        @matcher = matcher
      end
    end

    def match?(key)
      !@matcher.match?(key)
    end

    def equals?(obj)
      if obj.nil?
        return false
      elsif !obj.instance_of?(NegationMatcher)
        return false
      elsif this.equal?(obj)
        return true
      else
        return false
      end
    end

    def to_s
      "not " + @matcher.to_s
    end

  end

end