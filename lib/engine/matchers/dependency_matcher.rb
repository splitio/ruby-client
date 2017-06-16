module SplitIoClient
  class DependencyMatcher
    def self.matcher_type
      'IN_SPLIT_TREATMENT'.freeze
    end

    def initialize(split, treatments)
      @split = split
      @treatments = treatments
    end

    def match?(key, split_treatment, attributes)
      @treatments.include? split_treatment.call({ matching_key: key }, @split, attributes)[:treatment]
    end
  end
end
