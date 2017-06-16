module SplitIoClient
  class DependencyMatcher
    def self.matcher_type
      'IN_evaluator'.freeze
    end

    def initialize(split, treatments)
      @split = split
      @treatments = treatments
    end

    def match?(key, evaluator, attributes)
      @treatments.include? evaluator.call({ matching_key: key }, @split, attributes)[:treatment]
    end
  end
end
