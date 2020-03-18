# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      StreamData = Struct.new(:event_type, :client_id, :data)
    end
  end
end
