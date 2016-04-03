module SplitIoClient

  class EqualToMatcher < NoMethodError

    attr_reader :matcher_type

    def initialize(attribute_hash)
      @matcher_type = "EQUAL_TO"
      @attribute = attribute_hash[:attribute]
      @value =  attribute_hash[:value]
      @data_type = attribute_hash[:data_type]
    end

    def match?(attributes)
      matches = false
      if (!attributes.nil? && attributes.key?(@attribute.to_sym))
        param_value = get_formatted_value(attributes[@attribute.to_sym])
        matches = (param_value == @value)
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
    def get_formatted_value(value)
      case @data_type
        when "NUMBER"
          return value
        when "DATETIME"
          return ::Utilities.to_milis_zero_out_from_hour value
        else
          @logger.error('Invalid data type')
      end
    end

  end

end
