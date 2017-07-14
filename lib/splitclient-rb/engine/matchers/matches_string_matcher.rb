module SplitIoClient
  class MatchesStringMatcher
    def self.matcher_type
      'MATCHES_STRING'.freeze
    end

    def initialize(attribute, regexp_string)
      @attribute = attribute
      @regexp_string = regexp_string
    end

    def match?(_key, data)
      value = data.fetch(@attribute) { |attr| data[attr.to_s] || data[attr.to_sym] }

      if @regexp_string.is_a? Regexp
        (value =~ @regexp_string) != nil
      else
        # String here
        value == @regexp_string
      end
    end
  end
end
