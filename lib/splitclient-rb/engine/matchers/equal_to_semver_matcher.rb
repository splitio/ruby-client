# frozen_string_literal: true

module SplitIoClient
  class EqualToSemverMatcher < Matcher
    MATCHER_TYPE = 'EQUAL_TO_SEMVER'

    attr_reader :attribute

    def initialize(attribute, string_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver = SplitIoClient::Semver.build(string_value, logger)
      @logger = logger
    end

    def match?(args)
      return false unless verify_semver_arg?(args, 'EqualsToSemverMatcher')

      value_to_match = SplitIoClient::Semver.build(args[:attributes][@attribute.to_sym], @logger)
      return false unless check_semver_value_to_match(value_to_match, MATCHER_TYPE)

      matches = (@semver.version == value_to_match.version)
      @logger.debug("[EqualsToSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
