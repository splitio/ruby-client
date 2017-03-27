module SplitIoClient
  #
  # represents the possible return values for a treatment
  #
  class Treatments < NoMethodError
    # Constants to represent treatment values
    CONTROL = 'control'.freeze
    OFF = 'off'.freeze
    ON = 'on'.freeze

    # get the actual value for the given treatment type
    #
    # @param type [string] treatment type
    #
    # @return [Treatment] treatment type value
    def self.get_type(type)
      case type
      when 'on'
        ON
      when 'off', 'control'
        return CONTROL
      else # default return off
        CONTROL
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
