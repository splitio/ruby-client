module SplitIoClient

  #
  # class to implement the user defined matcher
  #
  class WhitelistMatcher < NoMethodError

    attr_reader :matcher_type

    # variable that contains the keys of the whitelist
    @whitelist = []

    def initialize(whitelist_data)
      if whitelist_data.instance_of? Array
        @whitelist = whitelist_data unless whitelist_data.nil?
      elsif whitelist_data.instance_of? Hash
        @matcher_type = "ATTR_WHITELIST"
        @attribute = whitelist_data[:attribute]
        @whitelist = whitelist_data[:value] unless whitelist_data[:value].nil?
      end
    end

    def match?(key, _evaluator, whitelist_data)
      matches = false
      if !(@matcher_type == "ATTR_WHITELIST")
        matches = @whitelist.include?(key)
      else
        if (!whitelist_data.nil? && whitelist_data.key?(@attribute.to_sym))
          value = whitelist_data[@attribute.to_sym]
          matches = @whitelist.include?(value)
        end
      end
      matches
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

    #
    # function to print string value for this matcher
    #
    # @reutrn [string] string value of this matcher
    def to_s
      'in segment ' + @whitelist.to_s
    end

  end

end
