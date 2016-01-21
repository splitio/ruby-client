module SplitIoClient

  class AllKeysMatcher < NoMethodError

    def match?(key)
      true
    end

    def equals?(obj)

      if obj.nil?
        return false
      elsif self.equal?(obj)
        return true
      elsif !obj.instance_of?(AllKeysMatcher)
        return false
      else
        return true
      end

    end

    def to_s
      "in segment all"
    end

  end

end