module SplitIoClient
  class EndsWithMatcher
    def self.matcher_type
      'ENDS_WITH'.freeze
    end

    def initialize(attribute, suffix_list)
      @attribute = attribute
      @suffix_list = suffix_list
    end

    def match?(value, _matching_key, _bucketing_key, _evaluator)
      return false if @suffix_list.empty?

      @suffix_list.any? { |suffix| value.to_s.end_with? suffix }
    end
  end
end
