module SplitIoClient
  class MatchesStringMatcher
    def self.matcher_type
      'MATCHES_STRING'.freeze
    end

    def initialize(attribute, regexp_string)
      @attribute = attribute
      @regexp_string = @regexp_string.is_a?(Regexp) ? regexp_string : Regexp.new(regexp_string)
    end

    def match?(value, _matching_key, _bucketing_key, _evaluator)
      (value =~ @regexp_string) != nil
    end
  end
end
