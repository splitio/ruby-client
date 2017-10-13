module SplitIoClient
  class DependencyMatcher
    MATCHER_TYPE = 'IN_SPLIT_TREATMENT'.freeze

    def initialize(split, treatments)
      @split = split
      @treatments = treatments
    end

    def match?(args)
      keys = { matching_key: args[:matching_key], bucketing_key: args[:bucketing_key] }

      @treatments.include?(args[:evaluator].call(keys, @split, args[:attributes])[:treatment])
    end

    def string_type?
      false
    end
  end
end
