# frozen_string_literal: true

module SplitIoClient
  class EndsWithMatcher
    MATCHER_TYPE = 'ENDS_WITH'

    attr_reader :attribute

    def initialize(attribute, suffix_list)
      @attribute = attribute
      @suffix_list = suffix_list
    end

    def match?(args)
      value = args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end
      SplitLogger.log_if_debug("[EndsWithMatcher] Value from parameters: #{value}.")

      if @suffix_list.empty?
        SplitLogger.log_if_debug('[EndsWithMatcher] Sufix List empty.')
        return false
      end

      matches = @suffix_list.any? { |suffix| value.to_s.end_with? suffix }
      SplitLogger.log_if_debug("[EndsWithMatcher] #{value} ends with any #{@suffix_list}")
      matches
    end

    def string_type?
      true
    end
  end
end
