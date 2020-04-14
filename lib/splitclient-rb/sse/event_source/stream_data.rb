# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      class StreamData
        attr_reader :event_type, :channel, :data, :client_id

        def initialize(event_type, client_id, data, channel)
          @event_type = event_type
          @client_id = client_id
          @data = data
          @channel = channel&.gsub(SplitIoClient::Constants::OCCUPANCY_CHANNEL_PREFIX, '')
        end

        def occupancy?
          @channel.include? 'occupancy'
        end
      end
    end
  end
end
