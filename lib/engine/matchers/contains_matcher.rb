module SplitIoClient
  class ContainsMatcher
    def self.matcher_type
      'CONTAINS_WITH'.freeze
    end

    def initialize(attribute, substr_list)
      @attribute = attribute
      @substr_list = substr_list
    end

    def match?(_key, data)
      value = data.fetch(@attribute) { |attr| data[attr.to_s] || data[attr.to_sym] }

      return false if @substr_list.empty?

      @substr_list.any? { |substr| value.to_s.include? substr }
    end
  end
end
