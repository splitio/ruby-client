# frozen_string_literal: true

module SplitIoClient
  class BetweenMatcher < Matcher
    MATCHER_TYPE = 'BETWEEN'

    attr_reader :attribute

    def initialize(attribute_hash, logger, validator)
      super(logger)
      @validator = validator
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @start_value = formatted_value(attribute_hash[:start_value], true)
      @end_value = formatted_value(attribute_hash[:end_value], true)
    end

    def match?(args)
      @logger.log_if_debug('[BetweenMatcher] evaluating value and attributes.')

      return false unless @validator.valid_matcher_arguments(args)

      value = formatted_value(args[:value] || args[:attributes][@attribute.to_sym])
      @logger.log_if_debug("[BetweenMatcher] Value from parameters: #{value}.")
      return false unless value.is_a?(Integer)

      matches = (@start_value..@end_value).cover? value
      @logger.log_if_debug("[BetweenMatcher] is #{value} between #{@start_value} and #{@end_value} -> #{matches} .")
      matches
    end

    private

    def formatted_value(value, sdk_data = false)
      case @data_type
      when 'NUMBER'
        value
      when 'DATETIME'
        value /= 1000 if sdk_data

        SplitIoClient::Utilities.to_milis_zero_out_from_seconds(value)
      else
        @logger.error('Invalid data type')
      end
    end
  end
end
