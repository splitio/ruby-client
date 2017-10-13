module SplitIoClient
  #
  # class to implement the user defined matcher
  #
  class WhitelistMatcher < NoMethodError
    MATCHER_TYPE = 'WHITELIST_MATCHER'

    attr_reader :attribute

    def initialize(whitelist_data)
      @whitelist = case whitelist_data
      when Array
        whitelist_data
      when Hash
        @matcher_type = 'ATTR_WHITELIST'
        @attribute = whitelist_data[:attribute]

        whitelist_data[:value]
      else
        []
      end
    end

    def match?(args)
      return @whitelist.include?(args[:value] || args[:matching_key]) unless @matcher_type == 'ATTR_WHITELIST'

      return false if !args.key?(:attributes) && !args.key?(:value)
      return false if args.key?(:value) && args[:value].nil?
      return false if args.key?(:attributes) && args[:attributes].nil?

      return @whitelist.include?(args[:value] || args[:attributes][@attribute.to_sym])

      false
    end

    #
    # evaluates if the given object equals the matcher
    #
    # @param obj [object] object to be evaluated
    #
    # @returns [boolean] true if obj equals the matcher
    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(WhitelistMatcher)
        false
      elsif self.equal?(obj)
        true
      else
        false
      end
    end

    def string_type?
      true
    end

    #
    # function to print string value for this matcher
    #
    # @reutrn [string] string value of this matcher
    def to_s
      "in segment #{@whitelist}"
    end
  end
end
