module SplitIoClient
  class ContainsAnyMatcher < SetMatcher
    MATCHER_TYPE = 'CONTAINS_ANY'.freeze

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      local_set(args[:attributes], @attribute).intersect? @remote_set
    end

    def string_type?
      false
    end
  end
end
