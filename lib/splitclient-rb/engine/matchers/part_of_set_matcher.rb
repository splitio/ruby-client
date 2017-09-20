module SplitIoClient
  class PartOfSetMatcher < SetMatcher
    MATCHER_TYPE = 'PART_OF_SET'.freeze

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      @local_set = local_set(args[:attributes], @attribute)

      return false if @local_set.empty?

      @local_set.subset? @remote_set
    end

    def string_type?
      false
    end
  end
end
