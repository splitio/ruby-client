module SplitIoClient

  class WhitelistMatcher < NoMethodError

    @whitelist = []

    def initialize(whitelist)
      if !whitelist.nil?
        @whitelist = whitelist
      end
    end

    def match?(key)
      @whitelist.include?(key)
    end

    def equals?(obj)
      if obj.nil?
        return false
      elsif !obj.instance_of?(WhitelistMatcher)
        return false
      elsif this.equal?(obj)
        return true
      else
        return false
      end
    end

    def to_s
      "in segment " + @whitelist.to_s
    end

  end

end