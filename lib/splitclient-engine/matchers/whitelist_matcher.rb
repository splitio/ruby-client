module SplitIoClient

  class WhitelistMatcher < NoMethodError

    @whitelist = []

    def initialize(whitelist)
      unless whitelist.nil?
        @whitelist = whitelist
      end
    end

    def match?(key)
      @whitelist.include?(key)
    end

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

    def to_s
      'in segment ' + @whitelist.to_s
    end

  end

end