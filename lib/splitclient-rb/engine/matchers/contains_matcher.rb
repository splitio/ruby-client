# frozen_string_literal: true

module SplitIoClient
  class ContainsMatcher
    MATCHER_TYPE = 'CONTAINS_WITH'

    attr_reader :attribute

    def initialize(attribute, substr_list, logger, validator)
      @attribute = attribute
      @substr_list = substr_list
      @logger = logger
      @validator = validator
    end

    def match?(args)
      @logger.log_if_debug('[ContainsMatcher] evaluating value and attributes.')

      return false unless @validator.valid_matcher_arguments(args)

      value = get_value(args)

      @logger.log_if_debug("[ContainsMatcher] Value from parameters: #{value}.")
      return false if @substr_list.empty?

      matches = @substr_list.any? { |substr| value.to_s.include? substr }
      @logger.log_if_debug("[ContainsMatcher] #{@value} contains any of #{@substr_list} -> #{matches} .")
      matches
    end

    def string_type?
      true
    end

    private

    def get_value(args)
      args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end
    end
  end
end
