# frozen_string_literal: true

module SplitIoClient
  class BetweenSemverMatcher < Matcher
    MATCHER_TYPE = 'BETWEEN_SEMVER'

    attr_reader :attribute

    def initialize(attribute, start_value, end_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver_start = SplitIoClient::Semver.build(start_value, logger)
      @semver_end = SplitIoClient::Semver.build(end_value, logger)
      @logger = logger
    end

    def match?(args)
      return false if !verify_semver_arg?(args, "BetweenSemverMatcher")

      value_to_match = SplitIoClient::Semver.build(args[:attributes][@attribute.to_sym], @logger)
      unless !value_to_match.nil? && !@semver_start.nil? && !@semver_end.nil?
        @logger.error('betweenStringMatcherData is required for BETWEEN_SEMVER matcher type')
        return false

      end
      matches = ([0, -1].include?(@semver_start.compare(value_to_match)) &&
                 [0, 1].include?(@semver_end.compare(value_to_match)))
      @logger.debug("[BetweenMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
