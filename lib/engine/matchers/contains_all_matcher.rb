module SplitIoClient
  class ContainsAllMatcher < SetMatcher
    def self.matcher_type
      'CONTAINS_ALL'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(_matching_key, _bucketing_key, _evaluator, data)
      return false if @remote_set.empty?

      @remote_set.subset? local_set(data, @attribute)
    end
  end
end
