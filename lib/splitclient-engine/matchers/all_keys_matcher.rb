module SplitIoClient

  class AllKeysMatcher < NoMethodError

    def match?(key)
      true
    end

    def equals?(obj)

      if obj.nil?
        return false
      end

      if this.equal?(obj)
        return true
      end

      if !obj.instance_of?(AllKeysMatcher)
        return false
      end

      true

    end

    def to_s
      "in segment all"
    end

  end

end