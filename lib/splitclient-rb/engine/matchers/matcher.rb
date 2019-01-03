# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the all keys matcher
  #
  class Matcher
    #
    # evaluates if the given object equals the matcher
    #
    # @param obj [object] object to be evaluated
    #
    # @return [boolean] true if obj equals the matcher
    def equals?(obj)
      if obj.nil?
        false
      elsif !obj.instance_of?(self.class)
        false
      elsif equal?(obj)
        true
      else
        false
      end
    end

    def string_type?
      false
    end

  end
end
