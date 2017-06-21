module SplitIoClient
  class EqualToBooleanMatcher
    def self.matcher_type
      'EQUAL_TO_BOOLEAN'.freeze
    end

    def initialize(attribute, boolean)
      @attribute = attribute
      @boolean = boolean
    end

    def match?(_key, data)
      value = data.fetch(@attribute) { |attr| data[attr.to_s] || data[attr.to_sym] }

      value == @boolean
    end
  end
end
