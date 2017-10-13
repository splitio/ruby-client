module SplitIoClient
  class EqualToMatcher
    MATCHER_TYPE = 'EQUAL_TO'.freeze

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

      value.is_a?(Integer) ? (value == @value) : false
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(EqualToMatcher)
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
        value
      when 'DATETIME'
        value = value / 1000 if sdk_data

        SplitIoClient::Utilities.to_milis_zero_out_from_hour value
      else
        @logger.error('Invalid data type')
      end
    end
  end
end
