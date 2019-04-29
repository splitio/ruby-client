# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the negation of a matcher
  #
  class NegationMatcher < Matcher
    MATCHER_TYPE = 'NEGATION_MATCHER'

    def initialize(config, matcher = nil)
      super(config)
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
      @config.log_if_debug("[NegationMatcherMatcher] Matcher #{@matcher} Arguments #{args} -> #{matches}")
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
    # function to print string value for this matcher
    #
    # @return [string] string value of this matcher
    def to_s
      "not #{@matcher}"
    end
  end
end
