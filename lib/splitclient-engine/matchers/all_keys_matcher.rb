module SplitIoClient

  class AllKeysMatcher < NoMethodError

    def match?(key)
      true
    end

    def equals?(obj)
      if obj.nil?
        false
      elsif self.equal?(obj)
        true
      elsif !obj.instance_of?(AllKeysMatcher)
        false
      else
        true
      end
    end

    def to_s
      'in segment all'
    end

  end

end