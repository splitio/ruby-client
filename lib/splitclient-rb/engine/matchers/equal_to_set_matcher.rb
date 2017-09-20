module SplitIoClient
  class EqualToSetMatcher < SetMatcher
    MATCHER_TYPE = 'EQUAL_TO_SET'.freeze

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      local_set(args[:attributes], @attribute) == @remote_set
    end

    def string_type?
      false
    end
  end
end
