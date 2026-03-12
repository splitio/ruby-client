# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Events
      class NoOpEventsQueue
        def push(sdk_event)
          # do nothing
        end
      end
    end
  end
end
