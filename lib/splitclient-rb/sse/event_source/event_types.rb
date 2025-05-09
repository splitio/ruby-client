# frozen_string_literal: true

module SplitIoClient
  module SSE
    module EventSource
      class EventTypes
        SPLIT_UPDATE = 'SPLIT_UPDATE'
        SPLIT_KILL = 'SPLIT_KILL'
        SEGMENT_UPDATE = 'SEGMENT_UPDATE'
        CONTROL = 'CONTROL'
        RB_SEGMENT_UPDATE = 'RB_SEGMENT_UPDATE'
      end
    end
  end
end
