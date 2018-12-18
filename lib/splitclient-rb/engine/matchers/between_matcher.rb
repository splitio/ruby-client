module SplitIoClient
  class BetweenMatcher
    MATCHER_TYPE = 'BETWEEN'.freeze

    attr_reader :attribute

    def initialize(attribute_hash)
      @attribute = attribute_hash[:attribute]
      @data_type = attribute_hash[:data_type]
      @start_value = formatted_value(attribute_hash[:start_value], true)
      @end_value = formatted_value(attribute_hash[:end_value], true)
    end

    def match?(args)
      SplitLogger.log_if_debug("[BetweenMatcher] evaluating value and attributes.");
      return false if !args.key?(:attributes) && !args.key?(:value)
      return false if args.key?(:value) && args[:value].nil?
      return false if args.key?(:attributes) && args[:attributes].nil?

      value = formatted_value(args[:value] || args[:attributes][@attribute.to_sym])
      SplitLogger.log_if_debug("[BetweenMatcher] Value from parameters: #{value}.");
      return false unless value.is_a?(Integer)

      matches = (@start_value..@end_value).include? value
      SplitLogger.log_if_debug("[BetweenMatcher] is #{value} between #{@start_value} and #{@end_value} -> #{matches} .");

      matches
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

        SplitIoClient::Utilities.to_milis_zero_out_from_seconds(value)
      else
        @logger.error('Invalid data type')
      end
    end
  end
end
