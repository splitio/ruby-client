module SplitIoClient
  class EqualToSetMatcher < SetMatcher
    def self.matcher_type
      'EQUAL_TO_SET'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(data, bucketing_key, _evaluator, _attributes)
      local_set(data) == @remote_set
    end
  end
end
