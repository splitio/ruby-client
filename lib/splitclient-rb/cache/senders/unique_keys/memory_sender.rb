# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class MemoryUniqueKeysSender < UniqueKeysSenderAdapter
        def initialize(config)
          @config = config
        end

        def record_uniques_key(uniques)
          # TODO: implementation
        end

        def record_impressions_count
          # TODO: implementation
        end
      end
    end
  end
end
