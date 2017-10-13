module SplitIoClient
  class GreaterThanOrEqualToMatcher
    MATCHER_TYPE = 'GREATER_THAN_OR_EQUAL_TO'.freeze

    attr_reader :attribute

    def initialize(attribute_hash)
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @value = formatted_value(attribute_hash[:value], true)
    end

    def match?(args)
      return false if !args.key?(:attributes) && !args.key?(:value)
      return false if args.key?(:value) && args[:value].nil?
      return false if args.key?(:attributes) && args[:attributes].nil?

      value = formatted_value(args[:value] || args[:attributes][@attribute.to_sym])

      value.is_a?(Integer) ? (value >= @value) : false
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(GreaterThanOrEqualToMatcher)
        false
      elsif self.equal?(obj)
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
        return value
      when 'DATETIME'
        value = value / 1000 if sdk_data # sdk returns already miliseconds, turning to seconds to do a correct zero_our
        return SplitIoClient::Utilities.to_milis_zero_out_from_seconds(value)
      else
        @logger.error('Invalid data type')
      end
    end
  end
end
