# frozen_string_literal: true

module SplitIoClient
  class LessThanOrEqualToMatcher
    MATCHER_TYPE = 'LESS_THAN_OR_EQUAL_TO'

    attr_reader :attribute

    def initialize(attribute_hash)
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @value = formatted_value(attribute_hash[:value], true)
    end

    def match?(args)
      SplitLogger.log_if_debug('[LessThanOrEqualToMatcher] evaluating value and attributes.')

      return false unless SplitIoClient::Validators.valid_matcher_arguments(args)

      value = formatted_value(args[:value] || args[:attributes][@attribute.to_sym])

      matches = value.is_a?(Integer) ? (value <= @value) : false
      SplitLogger.log_if_debug("[LessThanOrEqualToMatcher] #{value} less than or equal to #{@value} -> #{matches}")
      matches
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(LessThanOrEqualToMatcher)
        false
      elsif equal?(obj)
        true
      else
        false
      end
    end

    def string_type?
      false
    end

    private

    def formatted_value(value, sdk_data = false)
      case @data_type
      when 'NUMBER'
        value
      when 'DATETIME'
        value /= 1000 if sdk_data # sdk returns already miliseconds, turning to seconds to do a correct zero_hour
        SplitIoClient::Utilities.to_milis_zero_out_from_seconds(value)
      else
        @logger.error('Invalid data type')
      end
    end
  end
end
