module SplitIoClient
  class ContainsMatcher
    MATCHER_TYPE = 'CONTAINS_WITH'.freeze

    attr_reader :attribute

    def initialize(attribute, substr_list)
      @attribute = attribute
      @substr_list = substr_list
    end

    def match?(args)
      return false if !args.key?(:attributes) && !args.key?(:value)
      return false if args.key?(:value) && args[:value].nil?
      return false if args.key?(:attributes) && args[:attributes].nil?

      value = args[:value] || args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end

      return false if @substr_list.empty?

      @substr_list.any? { |substr| value.to_s.include? substr }
    end

    def string_type?
      true
    end
  end
end
