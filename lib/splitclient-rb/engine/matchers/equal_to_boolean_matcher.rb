module SplitIoClient
  class EqualToBooleanMatcher
    def self.matcher_type
      'EQUAL_TO_BOOLEAN'.freeze
    end

    def initialize(attribute, boolean)
      @attribute = attribute
      @boolean = boolean
    end

    def match?(value, _matching_key, _bucketing_key, _evaluator)
      value = false if value.to_s.downcase == 'false'
      value = true if value.to_s.downcase == 'true'

      value == @boolean
    end
  end
end
