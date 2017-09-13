module SplitIoClient
  class AttributeMatcher
    def initialize(attribute, matcher)
      @attribute = attribute
      @matcher = matcher
    end

    def match?(matching_key, bucketing_key, evaluator, attributes)
      if @attribute != nil
        return false unless attributes

        value = attributes.fetch(@attribute) { |name| attributes[name.to_s] || attributes[name.to_sym] }

        @matcher.match?(value, bucketing_key, nil, nil)
      else
        @matcher.match?(matching_key, bucketing_key, evaluator, attributes)
      end
    end
  end
end
