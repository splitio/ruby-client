module SplitIoClient
  class DependencyMatcher
    def self.matcher_type
      'IN_SPLIT_TREATMENT'.freeze
    end

    def initialize(split, treatments)
      @split = split
      @treatments = treatments
    end

    def match?(matching_key, bucketing_key, evaluator, attributes)
      @treatments.include? evaluator.call({ matching_key: matching_key, bucketing_key: bucketing_key }, @split, attributes)[:treatment]
    end
  end
end
