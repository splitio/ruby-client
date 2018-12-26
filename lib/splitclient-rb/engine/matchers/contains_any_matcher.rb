# frozen_string_literal: true

module SplitIoClient
  class ContainsAnyMatcher < SetMatcher
    MATCHER_TYPE = 'CONTAINS_ANY'

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      matches = local_set(args[:attributes], @attribute).intersect? @remote_set
      SplitLogger.log_if_debug("[ContainsAnyMatcher] Remote Set #{@remote_set} contains any \
        #{@attribute} or #{args[:attributes]}-> #{matches}")
      matches
    end

    def string_type?
      false
    end
  end
end
