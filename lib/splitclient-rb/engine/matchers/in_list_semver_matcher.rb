# frozen_string_literal: true

module SplitIoClient
  class InListSemverMatcher < Matcher
    MATCHER_TYPE = 'IN_LIST_SEMVER'

    attr_reader :attribute

    def initialize(attribute, list_value, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute
      @semver_list = list_value.map { |item| SplitIoClient::Semver.new(item)}
      @logger = logger
    end

    def match?(args)
      @logger.log_if_debug('[InListSemverMatcher] evaluating value and attributes.')
      return false unless @validator.valid_matcher_arguments(args)

      value_to_match = args[:attributes][@attribute.to_sym]
      unless value_to_match.is_a?(String)
        @logger.log_if_debug('whitelistMatcherData is required for IN_LIST_SEMVER matcher type')
        return false
      end
      matches = (@semver_list.map{ |item|  item.compare(SplitIoClient::Semver.new(value_to_match)) }).any? { |item| item == 0 }
      @logger.log_if_debug("[InListSemverMatcher] #{value_to_match} matches -> #{matches}")
      matches
    end
  end
end
