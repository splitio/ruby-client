module SplitIoClient
  class StartsWithMatcher
    MATCHER_TYPE = 'STARTS_WITH'.freeze

    attr_reader :attribute

    def initialize(attribute, prefix_list)
      @attribute = attribute
      @prefix_list = prefix_list
    end

    def match?(args)
      value = args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end

      return false if @prefix_list.empty?

      @prefix_list.any? { |prefix| value.to_s.start_with? prefix }
    end

    def string_type?
      true
    end
  end
end
