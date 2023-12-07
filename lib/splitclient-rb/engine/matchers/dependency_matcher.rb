# frozen_string_literal: true

module SplitIoClient
  class DependencyMatcher
    MATCHER_TYPE = 'IN_SPLIT_TREATMENT'

    def initialize(feature_flag, treatments, logger)
      @feature_flag = feature_flag
      @treatments = treatments
      @logger = logger
    end

    def match?(args)
      keys = { matching_key: args[:matching_key], bucketing_key: args[:bucketing_key] }
      evaluate = args[:evaluator].evaluate_feature_flag(keys, @feature_flag, args[:attributes])
      matches = @treatments.include?(evaluate[:treatment])
      @logger.log_if_debug("[dependencyMatcher] Parent feature flag #{@feature_flag} evaluated to #{evaluate[:treatment]} \
        with label #{evaluate[:label]}. #{@feature_flag} evaluated treatment is part of [#{@treatments}] ? #{matches}.")
      matches
    end

    def string_type?
      false
    end
  end
end
