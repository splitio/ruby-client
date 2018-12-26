# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the all keys matcher
  #
  class AllKeysMatcher
    MATCHER_TYPE = 'ALL_KEYS'

    #
    # evaluates if the key matches the matcher
    #
    # @return [boolean] true for all instances
    def match?(_args)
      SplitLogger.log_if_debug('[AllKeysMatcher] is always -> true')
      true
    end

    #
    # evaluates if the given object equals the matcher
    #
    # @param obj [object] object to be evaluated
    #
    # @return [boolean] true if obj equals the matcher
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

    def string_type?
      false
    end

    #
    # function to print string value for this matcher
    #
    # @return [string] string value of this matcher
    def to_s
      'in segment all'
    end
  end
end
