# frozen_string_literal: true

module SplitIoClient
  class StartsWithMatcher
    MATCHER_TYPE = 'STARTS_WITH'

    attr_reader :attribute

    def initialize(attribute, prefix_list)
      @attribute = attribute
      @prefix_list = prefix_list
    end

    def match?(args)
      value = args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end
      if @prefix_list.empty?
        SplitLogger.log_if_debug('[StartsWithMatcher] Prefix List is empty.')
        return false
      end

      matches = @prefix_list.any? { |prefix| value.to_s.start_with? prefix }
      SplitLogger.log_if_debug("[StartsWithMatcher] #{value} matches any of #{@prefix_list} -> #{matches}")
      matches
    end

    def string_type?
      true
    end
  end
end
