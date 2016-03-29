module SplitIoClient

  #
  # class to implement the user defined matcher
  #
  class WhitelistMatcher < NoMethodError

    # variable that contains the keys of the whitelist
    @whitelist = []

    def initialize(whitelist)
      unless whitelist.nil?
        @whitelist = whitelist
      end
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the key against the whitelist
    def match?(key)
      @whitelist.include?(key)
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