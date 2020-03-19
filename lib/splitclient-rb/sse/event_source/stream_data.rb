# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      class StreamData
        attr_reader :event_type, :client_id, :data
        def initialize(event_type, client_id, data)
          @event_type = event_type
          @client_id = client_id
          @data = data
        end
      end
    end
  end
end
