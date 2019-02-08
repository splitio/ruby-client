# frozen_string_literal: true

module SplitIoClient
  class ContainsAllMatcher < SetMatcher
    MATCHER_TYPE = 'CONTAINS_ALL'

    attr_reader :attribute

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(args)
      if @remote_set.empty?
        SplitLogger.log_if_debug('[ContainsAllMatcher] Remote Set Empty')
        return false
      end

      matches = @remote_set.subset? local_set(args[:attributes], @attribute)
      SplitLogger.log_if_debug("[ContainsAllMatcher] Remote Set #{@remote_set} contains #{@attribute} -> #{matches}")
      matches
    end
  end
end
