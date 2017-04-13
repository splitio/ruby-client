module SplitIoClient
  class ContainsAnyMatcher < SetMatcher
    def self.matcher_type
      'CONTAINS_ANY'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(_key, data)
      local_set(data, @attribute).intersect? @remote_set
    end
  end
end
