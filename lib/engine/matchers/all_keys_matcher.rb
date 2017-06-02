module SplitIoClient
  #
  # class to implement the all keys matcher
  #
  class AllKeysMatcher < NoMethodError
    attr_reader :matcher_type

    def initialize
      @matcher_type = 'ALL_KEYS'
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] true for all instances
    def match?(_key, _split_treatment, _attributes)
      true
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
      elsif equal?(obj)
        true
      elsif !obj.instance_of?(AllKeysMatcher)
        false
      else
        true
      end
    end

    #
    # function to print string value for this matcher
    #
    # @reutrn [string] string value of this matcher
    def to_s
      'in segment all'
    end
  end
end
