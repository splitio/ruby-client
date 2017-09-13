module SplitIoClient
  class StartsWithMatcher
    def self.matcher_type
      'STARTS_WITH'.freeze
    end

    def initialize(attribute, prefix_list)
      @attribute = attribute
      @prefix_list = prefix_list
    end

    def match?(value, _matching_key, _bucketing_key, _evaluator)
      return false if @prefix_list.empty?

      @prefix_list.any? { |prefix| value.to_s.start_with? prefix }
    end
  end
end
