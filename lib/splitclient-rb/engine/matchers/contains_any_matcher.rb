module SplitIoClient
  class ContainsAnyMatcher < SetMatcher
    def self.matcher_type
      'CONTAINS_ANY'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(data, bucketing_key, _evaluator, _attributes)
      local_set(data).intersect? @remote_set
    end
  end
end
