module SplitIoClient

  class LessThanOrEqualToMatcher < NoMethodError

    attr_reader :matcher_type

    def initialize(attribute_hash)
      @matcher_type = "LESS_THAN_OR_EQUAL_TO"
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @value = get_formatted_value attribute_hash[:value], true
    end

    def match?(value, _matching_key, _bucketing_key, _evaluator)
      matches = false
      if !value.nil?
        param_value = get_formatted_value(value)
        matches = param_value.is_a?(Integer) ? (param_value <= @value) : false
      end
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(LessThanOrEqualToMatcher)
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
          value = value/1000 if is_sdk_data # sdk returns already miliseconds, turning to seconds to do a correct zero_our
          return SplitIoClient::Utilities.to_milis_zero_out_from_seconds value
        else
          @logger.error('Invalid data type')
      end
    end

  end

end
