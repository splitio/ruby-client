module SplitIoClient
  class ContainsAllMatcher < SetMatcher
    def self.matcher_type
      'CONTAINS_ALL'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(data, bucketing_key, _evaluator, _attributes)
      return false if @remote_set.empty?

      @remote_set.subset? local_set(data)
    end
  end
end
