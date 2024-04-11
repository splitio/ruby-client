# frozen_string_literal: true

module SplitIoClient
  class GreaterThanOrEqualToSemverMatcher < Matcher
    MATCHER_TYPE = 'GREATER_THAN_OR_EQUAL_TO_SEMVER'

    attr_reader :attribute

    def initialize(attribute, string_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver = SplitIoClient::Semver.build(string_value, logger)
      @logger = logger
    end

    def match?(args)
      @logger.debug('[GreaterThanOrEqualsToSemverMatcher] evaluating value and attributes.')
      return false unless @validator.valid_matcher_arguments(args)

      value_to_match = SplitIoClient::Semver.build(args[:attributes][@attribute.to_sym],  @logger)
      unless !value_to_match.nil? && !@semver.nil?
        @logger.error('stringMatcherData is required for GREATER_THAN_OR_EQUAL_TO_SEMVER matcher type')
        return false
      end
      matches = [0, 1].include?(@semver.compare(value_to_match))
      @logger.debug("[GreaterThanOrEqualsToSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
