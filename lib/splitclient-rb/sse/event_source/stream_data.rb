# frozen_string_literal: true

module SSE
  module EventSource
    StreamData = Struct.new(:id, :type, :name, :data, :channel)
  end
end
