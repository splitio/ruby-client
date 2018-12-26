# frozen_string_literal: true

module SplitIoClient
  class EqualToBooleanMatcher
    MATCHER_TYPE = 'EQUAL_TO_BOOLEAN'

    attr_reader :attribute

    def initialize(attribute, boolean)
      @attribute = attribute
      @boolean = boolean
    end

    def match?(args)
      value = args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end

      value = false if value.to_s.casecmp('false').zero?
      value = true if value.to_s.casecmp('true').zero?

      matches = value == @boolean
      SplitLogger.log_if_debug("[EqualToBooleanMatcher] #{value} equals to #{@boolean} -> #{matches}")
      matches
    end

    def string_type?
      false
    end
  end
end
