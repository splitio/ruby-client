# frozen_string_literal: true

module SplitIoClient
  class InListSemverMatcher < Matcher
    MATCHER_TYPE = 'IN_LIST_SEMVER'

    attr_reader :attribute

    def initialize(attribute, list_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver_list = []

      list_value.map do |item|
        version = SplitIoClient::Semver.build(item, logger)
        @semver_list << version unless version.nil?
      end
      @logger = logger
    end

    def match?(args)
      return false unless verify_semver_arg?(args, 'InListSemverMatcher')

      value_to_match = SplitIoClient::Semver.build(args[:attributes][@attribute.to_sym], @logger)
      if value_to_match.nil?
        @logger.error('whitelistMatcherData is required for IN_LIST_SEMVER matcher type')
        return false
      end
      matches = (@semver_list.map { |item| item.version == value_to_match.version }).any? { |item| item == true }
      @logger.debug("[InListSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
