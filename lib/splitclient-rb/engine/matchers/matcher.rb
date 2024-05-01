# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the all keys matcher
  #
  class Matcher
    def initialize(logger)
      @logger = logger
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

    private

    def verify_semver_arg?(args, matcher_name)
      @logger.debug("[#{matcher_name}] evaluating value and attributes.")
      return false unless @validator.valid_matcher_arguments(args)

      true
    end

    def check_semver_value_to_match(value_to_match, matcher_spec_name)
      unless !value_to_match.nil? && !@semver.nil?
        @logger.error("stringMatcherData is required for #{matcher_spec_name} matcher type")
        return false

      end
      true
    end
  end
end
