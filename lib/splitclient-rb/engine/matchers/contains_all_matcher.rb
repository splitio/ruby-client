module SplitIoClient
  class ContainsAllMatcher < SetMatcher
    MATCHER_TYPE = 'CONTAINS_ALL'.freeze

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      return false if @remote_set.empty?

      @remote_set.subset? local_set(args[:attributes], @attribute)
    end

    def string_type?
      false
    end
  end
end
