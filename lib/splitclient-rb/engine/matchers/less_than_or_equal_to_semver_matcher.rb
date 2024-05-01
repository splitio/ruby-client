# frozen_string_literal: true

module SplitIoClient
  class LessThanOrEqualToSemverMatcher < Matcher
    MATCHER_TYPE = 'LESS_THAN_OR_EQUAL_TO_SEMVER'

    attr_reader :attribute

    def initialize(attribute, string_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver = SplitIoClient::Semver.build(string_value, logger)
      @logger = logger
    end

    def match?(args)
      return false if !verify_semver_arg?(args, "LessThanOrEqualsToSemverMatcher")

      value_to_match = SplitIoClient::Semver.build(args[:attributes][@attribute.to_sym], @logger)
      return false if !check_semver_value_to_match(value_to_match, MATCHER_TYPE)

      matches = [0, -1].include?(value_to_match.compare(@semver))
      @logger.debug("[LessThanOrEqualsToSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
