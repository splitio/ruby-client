module SplitIoClient

  class Treatments < NoMethodError

    # Constants to represent treatment values
    CONTROL = 'control'
    OFF     = 'off'
    ON      = 'on'

    # get the actual value for the given treatment type
    #
    # @param type [string] treatment type
    #
    # @return [Treatment] treatment type value
    def get_type(type)
      case type
        when 'on'
            return ON
        when 'off', 'control'
            return OFF
        else
            #TODO : log invalid treatment type error
      end
    end

    # checks if the give treatment matches control type
    #
    # @param type [string] treatment type
    #
    # @return [boolean] true if matches, false otherwise
    def self.is_control?(type)
      return type == CONTROL ? true : false
    end

  end

end