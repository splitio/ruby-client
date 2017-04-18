module SplitIoClient
  class StartsWithMatcher
    def self.matcher_type
      'STARTS_WITH'.freeze
    end

    def initialize(attribute, prefix)
      @attribute = attribute
      @prefix = prefix
    end

    def match?(_key, data)
      value = data.fetch(@attribute) { |attr| data[attr.to_s] || data[attr.to_sym] }

      return false if @prefix == ''

      value.start_with? @prefix
    end
  end
end
