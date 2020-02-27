# frozen_string_literal: true

module SplitIoClient
  module SSE
    module EventSource
      class EventTypes
        SPLIT_UPDATE = 'split_update'
        SPLIT_KILL = 'split_kill'
        SEGMENT_UPDATE = 'segment_update'
        CONTROL = 'control'
      end
    end
  end
end
