module SplitIoClient
  class EqualToSetMatcher < SetMatcher
    def self.matcher_type
      'EQUAL_TO_SET'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(_matching_key, _bucketing_key, _evaluator, data)
      local_set(data, @attribute) == @remote_set
    end
  end
end
