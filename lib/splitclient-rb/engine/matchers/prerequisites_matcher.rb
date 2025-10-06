# frozen_string_literal: true

module SplitIoClient
  class PrerequisitesMatcher
    def initialize(prerequisites, logger)
      @prerequisites = prerequisites
      @logger = logger
    end

    def match?(args)
      keys = { matching_key: args[:matching_key], bucketing_key: args[:bucketing_key] }

      match = true
      @prerequisites.each do |prerequisite|
        evaluate = args[:evaluator].evaluate_feature_flag(keys, prerequisite[:n], args[:attributes])
        next if prerequisite[:ts].include?(evaluate[:treatment])

        @logger.log_if_debug("[PrerequisitesMatcher] feature flag #{prerequisite[:n]} evaluated to #{evaluate[:treatment]} \
          that does not exist in prerequisited treatments.")
        match = false
        break
      end

      match
    end

    def string_type?
      false
    end
  end
end
