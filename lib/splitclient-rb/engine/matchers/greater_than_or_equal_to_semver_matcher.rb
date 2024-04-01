# frozen_string_literal: true

module SplitIoClient
  class GreaterThanOrEqualToSemverMatcher < Matcher
    MATCHER_TYPE = 'GREATER_THAN_OR_EQUAL_TO_SEMVER'

    attr_reader :attribute

    def initialize(attribute, string_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver = SplitIoClient::Semver.new(string_value)
      @logger = logger
    end

    def match?(args)
      @logger.log_if_debug('[GreaterThanOrEqualsToSemverMatcher] evaluating value and attributes.')
      return false unless @validator.valid_matcher_arguments(args)

      value_to_match = args[:attributes][@attribute.to_sym]
      unless value_to_match.is_a?(String)
        @logger.log_if_debug('stringMatcherData is required for GREATER_THAN_OR_EQUAL_TO_SEMVER matcher type')
        return false
      end
      matches = [0, 1].include?(@semver.compare(SplitIoClient::Semver.new(value_to_match)))
      @logger.log_if_debug("[GreaterThanOrEqualsToSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end