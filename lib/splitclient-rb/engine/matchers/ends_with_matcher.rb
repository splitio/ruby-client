module SplitIoClient
  class EndsWithMatcher
    MATCHER_TYPE = 'ENDS_WITH'.freeze

    attr_reader :attribute

    def initialize(attribute, suffix_list)
      @attribute = attribute
      @suffix_list = suffix_list
    end

    def match?(args)
      value = args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end

      return false if @suffix_list.empty?

      @suffix_list.any? { |suffix| value.to_s.end_with? suffix }
    end

    def string_type?
      true
    end
  end
end
