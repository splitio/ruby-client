module SplitIoClient

  class NegationMatcher < NoMethodError

    @matcher = nil

    def initialize(matcher)
      unless matcher.nil?
        @matcher = matcher
      end
    end

    def match?(key)
      !@matcher.match?(key)
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(NegationMatcher)
        false
      elsif self.equal?(obj)
        true
      else
        false
      end
    end

    def to_s
      'not ' + @matcher.to_s
    end

  end

end