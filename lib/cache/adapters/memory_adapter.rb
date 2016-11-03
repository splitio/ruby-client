require 'concurrent'

module SplitIoClient
  module Cache
    module Adapters
      # Memory adapter can have different implementations, this class is used as a delegator to
      # this implementations
      class MemoryAdapter < SimpleDelegator
      end
    end
  end
end
