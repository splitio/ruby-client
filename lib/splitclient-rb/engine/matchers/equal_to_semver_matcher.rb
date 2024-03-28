# frozen_string_literal: true

module SplitIoClient
  class EqualToSemverMatcher < Matcher
    MATCHER_TYPE = 'EQUAL_TO_SEMVER'

    attr_reader :attribute

    def initialize(attribute, string_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver = SplitIoClient::Semver.new(string_value)
      @logger = logger
    end

    def match?(args)
      @logger.log_if_debug('[EqualsToSemverMatcher] evaluating value and attributes.')
      return false unless @validator.valid_matcher_arguments(args)

      value_to_match = args[:attributes][@attribute.to_sym]
      unless value_to_match.is_a?(String)
        @logger.error('stringMatcherData is required for EQUAL_TO_SEMVER matcher type')
        return false
      end
      matches = @semver.compare(SplitIoClient::Semver.new(value_to_match)).zero?
      @logger.log_if_debug("[EqualsToSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
