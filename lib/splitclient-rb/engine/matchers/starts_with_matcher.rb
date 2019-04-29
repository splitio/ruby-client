# frozen_string_literal: true

module SplitIoClient
  class StartsWithMatcher
    MATCHER_TYPE = 'STARTS_WITH'

    attr_reader :attribute

    def initialize(attribute, prefix_list, config)
      @attribute = attribute
      @prefix_list = prefix_list
      @config = config
    end

    def match?(args)
      if @prefix_list.empty?
        @config.log_if_debug('[StartsWithMatcher] Prefix List is empty.')
        return false
      end

      value = get_value(args)

      matches = @prefix_list.any? { |prefix| value.to_s.start_with? prefix }
      @config.log_if_debug("[StartsWithMatcher] #{value} matches any of #{@prefix_list} -> #{matches}")
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
