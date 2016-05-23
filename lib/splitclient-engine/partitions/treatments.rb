module SplitIoClient

  #
  # represents the possible return values for a treatment
  #
  class Treatments < NoMethodError

    # Constants to represent treatment values
    CONTROL = 'control'
    OFF = 'off'
    ON = 'on'

    # get the actual value for the given treatment type
    #
    # @param type [string] treatment type
    #
    # @return [Treatment] treatment type value
    def self.get_type(type)
      case type
        when 'on'
          return ON
        when 'off', 'control'
          return CONTROL
        else # default return off
          return CONTROL
      end
    end

    # checks if the give treatment matches control type
    #
    # @param type [string] treatment type
    #
    # @return [boolean] true if matches, false otherwise
    def self.is_control?(treatment)
      get_type(treatment).equal?(CONTROL) ? true : false
    end

  end

end