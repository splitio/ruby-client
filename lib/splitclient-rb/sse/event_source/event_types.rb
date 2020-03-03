# frozen_string_literal: true

module SplitIoClient
  module SSE
    module EventSource
      class EventTypes
        SPLIT_UPDATE = 'SPLIT_UPDATE'
        SPLIT_KILL = 'SPLIT_KILL'
        SEGMENT_UPDATE = 'SEGMENT_UPDATE'
        CONTROL = 'CONTROL'
      end
    end
  end
end
