module SplitIoClient

  #
  # class to implement the negation of a matcher
  #
  class NegationMatcher < NoMethodError

    @matcher = nil

    def initialize(matcher)
      unless matcher.nil?
        @matcher = matcher
      end
    end

    #
    # evaluates if the key matches the negation of the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the negation matcher
    def match?(matching_key, bucketing_key, evaluator, attributes)
      !@matcher.match?(matching_key, bucketing_key, evaluator, attributes)
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
      elsif !obj.instance_of?(NegationMatcher)
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
      'not ' + @matcher.to_s
    end

  end

end
