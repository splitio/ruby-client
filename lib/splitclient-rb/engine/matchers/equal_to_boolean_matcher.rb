module SplitIoClient
  class EqualToBooleanMatcher
    MATCHER_TYPE = 'EQUAL_TO_BOOLEAN'.freeze

    attr_reader :attribute

    def initialize(attribute, boolean)
      @attribute = attribute
      @boolean = boolean
    end

    def match?(args)
      value = args[:attributes].fetch(@attribute) do |a|
        args[:attributes][a.to_s] || args[:attributes][a.to_sym]
      end

      value = false if value.to_s.downcase == 'false'
      value = true if value.to_s.downcase == 'true'

      value == @boolean
    end

    def string_type?
      false
    end
  end
end
