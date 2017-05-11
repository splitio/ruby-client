module SplitIoClient
  class EndsWithMatcher
    def self.matcher_type
      'ENDS_WITH'.freeze
    end

    def initialize(attribute, suffix_list)
      @attribute = attribute
      @suffix_list = suffix_list
    end

    def match?(_key, data)
      value = data.fetch(@attribute) { |attr| data[attr.to_s] || data[attr.to_sym] }

      return false if @suffix_list.empty?

      @suffix_list.any? { |suffix| value.to_s.end_with? suffix }
    end
  end
end
