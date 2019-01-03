# frozen_string_literal: true

module SplitIoClient
  class EqualToSetMatcher < SetMatcher
    MATCHER_TYPE = 'EQUAL_TO_SET'

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      set = local_set(args[:attributes], @attribute)
      matches = set == @remote_set
      SplitLogger.log_if_debug("[EqualsToSetMatcher] #{set} equals to #{@remote_set} -> #{matches}")
      matches
    end
  end
end
