module SplitIoClient
  #
  # class to implement the negation of a matcher
  #
  class NegationMatcher
    MATCHER_TYPE = 'NEGATION_MATCHER'.freeze

    def initialize(matcher = nil)
      @matcher = matcher
    end

    #
    # evaluates if the key matches the negation of the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the negation matcher
    def match?(args)
      matches = !@matcher.match?(args)
      SplitLogger.log_if_debug("[NegationMatcherMatcher] Matcher #{@matcher} Arguments #{args} -> #{matches}");
      matches
    end

    def respond_to?(method)
      @matcher.respond_to? method
    end

    def attribute
      @matcher.attribute
    end

    def string_type?
      @matcher.string_type?
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
      "not #{@matcher}"
    end
  end
end
