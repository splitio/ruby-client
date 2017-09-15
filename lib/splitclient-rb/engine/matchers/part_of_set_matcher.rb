module SplitIoClient
  class PartOfSetMatcher < SetMatcher
    def self.matcher_type
      'PART_OF_SET'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(data, bucketing_key, _evaluator, _attributes)
      @local_set = local_set(data)

      return false if @local_set.empty?

      @local_set.subset? @remote_set
    end
  end
end
