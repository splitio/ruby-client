# frozen_string_literal: true

module SplitIoClient
  class MatchesStringMatcher
    MATCHER_TYPE = 'MATCHES_STRING'

    attr_reader :attribute

    def initialize(attribute, regexp_string, logger)
      @attribute = attribute
      @regexp_string = @regexp_string.is_a?(Regexp) ? regexp_string : Regexp.new(regexp_string)
      @logger = logger
    end

    def match?(args)
      value = args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end

      matches = !(value =~ @regexp_string).nil?
      @logger.log_if_debug("[MatchesStringMatcher] #{value} matches #{@regexp_string} -> #{matches}")
      matches
    end

    def string_type?
      true
    end
  end
end
