# frozen_string_literal: true

module SplitIoClient
  class EqualToBooleanMatcher
    MATCHER_TYPE = 'EQUAL_TO_BOOLEAN'

    attr_reader :attribute

    def initialize(attribute, boolean, config)
      @attribute = attribute
      @boolean = boolean
      @config = config
    end

    def match?(args)
      value = get_value(args)
      value = false if value.to_s.casecmp('false').zero?
      value = true if value.to_s.casecmp('true').zero?

      matches = value == @boolean
      @config.log_if_debug("[EqualToBooleanMatcher] #{value} equals to #{@boolean} -> #{matches}")
      matches
    end

    def string_type?
      false
    end

    private

    def get_value(args)
      args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end
    end
  end
end
