module SplitIoClient
  class ContainsMatcher
    def self.matcher_type
      'CONTAINS_WITH'.freeze
    end

    def initialize(attribute, substr_list)
      @attribute = attribute
      @substr_list = substr_list
    end

    def match?(value, _matching_key, _bucketing_key, _evaluator)
      return false if @substr_list.empty?

      @substr_list.any? { |substr| value.to_s.include? substr }
    end
  end
end
