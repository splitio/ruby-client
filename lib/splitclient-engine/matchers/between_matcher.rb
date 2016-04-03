module SplitIoClient

  class BetweenMatcher < NoMethodError

    attr_reader :matcher_type

    def initialize(attribute_hash)
      @matcher_type = "BETWEEN"
      @attribute = attribute_hash[:attribute]
      @start_value =  attribute_hash[:start_value]
      @end_value =  attribute_hash[:end_value]
      @data_type = attribute_hash[:data_type]
    end

    def match?(attributes)
      matches = false
      if (!attributes.nil? && attributes.key?(@attribute.to_sym))
        param_value = get_formatted_value(attributes[@attribute.to_sym])
        matches = ((param_value >= @start_value) && (param_value <= @end_value))
      end
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(BetweenMatcher)
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
          return ::Utilities.to_milis_zero_out_from_seconds value
        else
          @logger.error('Invalid data type')
      end
    end
  end

end
