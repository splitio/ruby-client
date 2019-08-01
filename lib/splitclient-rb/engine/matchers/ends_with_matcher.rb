# frozen_string_literal: true

module SplitIoClient
  class EndsWithMatcher
    MATCHER_TYPE = 'ENDS_WITH'

    attr_reader :attribute

    def initialize(attribute, suffix_list, logger)
      @attribute = attribute
      @suffix_list = suffix_list
      @logger = logger
    end

    def match?(args)
      value = get_value(args)

      @logger.log_if_debug("[EndsWithMatcher] Value from parameters: #{value}.")

      if @suffix_list.empty?
        @logger.log_if_debug('[EndsWithMatcher] Sufix List empty.')
        return false
      end

      matches = @suffix_list.any? { |suffix| value.to_s.end_with? suffix }
      @logger.log_if_debug("[EndsWithMatcher] #{value} ends with any #{@suffix_list}")
      matches
    end

    def string_type?
      true
    end

    private

    def get_value(args)
      args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end
    end
  end
end
