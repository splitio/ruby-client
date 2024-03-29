# frozen_string_literal: true

module SplitIoClient
  class BetweenSemverMatcher < Matcher
    MATCHER_TYPE = 'BETWEEN_SEMVER'

    attr_reader :attribute

    def initialize(attribute, start_value, end_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver_start = SplitIoClient::Semver.new(start_value)
      @semver_end = SplitIoClient::Semver.new(end_value)
      @logger = logger
    end

    def match?(args)
      @logger.log_if_debug('[BetweenSemverMatcher] evaluating value and attributes.')
      return false unless @validator.valid_matcher_arguments(args)

      value_to_match = args[:attributes][@attribute.to_sym]
      unless value_to_match.is_a?(String)
        @logger.log_if_debug('betweenStringMatcherData is required for BETWEEN_SEMVER matcher type')
        return false
      end
      matches = ([0, -1].include?(@semver_start.compare(SplitIoClient::Semver.new(value_to_match))) &&
                 [0, 1].include?(@semver_end.compare(SplitIoClient::Semver.new(value_to_match))))
      @logger.log_if_debug("[BetweenMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
