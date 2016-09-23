module SplitIoClient

  class EqualToMatcher < NoMethodError

    attr_reader :matcher_type

    def initialize(attribute_hash)
      @matcher_type = "EQUAL_TO"
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @value = get_formatted_value attribute_hash[:value], true
    end

    def match?(key, attributes)
      matches = false
      if (!attributes.nil? && attributes.key?(@attribute.to_sym))
        param_value = get_formatted_value(attributes[@attribute.to_sym])
        matches = param_value.is_a?(Integer) ? (param_value == @value) : false
      end
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

    private
    def get_formatted_value(value, is_sdk_data = false)
      case @data_type
        when "NUMBER"
          return value
        when "DATETIME"
          value = value/1000 if is_sdk_data
          return ::Utilities.to_milis_zero_out_from_hour value
        else
          @logger.error('Invalid data type')
      end
    end

  end

end
