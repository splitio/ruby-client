# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the user defined matcher
  #
  class WhitelistMatcher < Matcher
    MATCHER_TYPE = 'WHITELIST_MATCHER'

    attr_reader :attribute

    def initialize(whitelist_data, logger, validator)
      super(logger)
      @validator = validator
      @whitelist = case whitelist_data
                   when Array
                     whitelist_data
                   when Hash
                     @matcher_type = 'ATTR_WHITELIST'
                     @attribute = whitelist_data[:attribute]

                     whitelist_data[:value]
                   else
                     []
                   end
    end

    def match?(args)
      return matches_user_whitelist(args) unless @matcher_type == 'ATTR_WHITELIST'

      @logger.log_if_debug('[WhitelistMatcher] evaluating value and attributes.')

      return false unless @validator.valid_matcher_arguments(args)

      matches_attr_whitelist(args)
    end

    def string_type?
      true
    end

    #
    # function to print string value for this matcher
    #
    # @return [string] string value of this matcher
    def to_s
      "in segment #{@whitelist}"
    end

    private

    def matches_user_whitelist(args)
      matches = @whitelist.include?(args[:value] || args[:matching_key])
      @logger.log_if_debug("[WhitelistMatcher] #{@whitelist} include \
        #{args[:value] || args[:matching_key]} -> #{matches}")
      matches
    end

    def matches_attr_whitelist(args)
      matches = @whitelist.include?(args[:value] || args[:attributes][@attribute.to_sym])
      @logger.log_if_debug("[WhitelistMatcher] #{@whitelist} include \
        #{args[:value] || args[:attributes][@attribute.to_sym]} -> #{matches}")
      matches
    end
  end
end
