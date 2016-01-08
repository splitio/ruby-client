module SplitClient

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

    def hash_code
      17
    end

    def to_s
      "in segment all"
    end

  end

end