# frozen_string_literal: true

module SplitIoClient
  class EqualToMatcher < Matcher
    MATCHER_TYPE = 'EQUAL_TO'

    attr_reader :attribute

    def initialize(attribute_hash, config)
      super(config)
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @value = formatted_value(attribute_hash[:value], true)
    end

    def match?(args)
      @config.log_if_debug('[EqualsToMatcher] evaluating value and attributes.')

      return false unless SplitIoClient::Validators.new(@config).valid_matcher_arguments(args)

      value = formatted_value(args[:value] || args[:attributes][@attribute.to_sym])

      matches = value.is_a?(Integer) ? (value == @value) : false
      @config.log_if_debug("[EqualsToMatcher] #{value} equals to #{@value} -> #{matches}")
      matches
    end

    private

    def formatted_value(value, sdk_data = false)
      case @data_type
      when 'NUMBER'
        value
      when 'DATETIME'
        value /= 1000 if sdk_data

        SplitIoClient::Utilities.to_milis_zero_out_from_hour value
      else
        @logger.error('Invalid data type')
      end
    end
  end
end
