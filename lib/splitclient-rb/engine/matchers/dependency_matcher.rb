module SplitIoClient
  class DependencyMatcher
    MATCHER_TYPE = 'IN_SPLIT_TREATMENT'.freeze

    def initialize(split, treatments)
      @split = split
      @treatments = treatments
    end

    def match?(args)
      keys = { matching_key: args[:matching_key], bucketing_key: args[:bucketing_key] }
      evaluate = args[:evaluator].call(keys, @split, args[:attributes])
      matches = @treatments.include?(evaluate[:treatment])
      SplitLogger.log_if_debug("[dependencyMatcher] Parent split #{@split} evaluated to #{evaluate[:treatment]} with label #{evaluate[:label]}. #{@split} evaluated treatment is part of [#{@treatments}] ? #{matches}.")
      matches
    end

    def string_type?
      false
    end
  end
end
