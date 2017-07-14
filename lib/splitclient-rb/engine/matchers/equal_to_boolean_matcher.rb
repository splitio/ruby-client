module SplitIoClient
  class EqualToBooleanMatcher
    def self.matcher_type
      'EQUAL_TO_BOOLEAN'.freeze
    end

    def initialize(attribute, boolean)
      @attribute = attribute
      @boolean = boolean
    end

    def match?(_matching_key, _bucketing_key, _evaluator, data)
      value = data.fetch(@attribute) { |attr| data[attr.to_s] || data[attr.to_sym] }

      value = [true, false].include?(value) ? value : value.to_s.downcase == 'true'

      value == @boolean
    end
  end
end
