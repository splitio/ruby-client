# frozen_string_literal: false

module SplitIoClient
  module SSE
    module EventSource
      class EventParser
        def initialize(config)
          @config = config
        end

        def parse(raw_event)
          type = nil
          events = []
          buffer = read_partial_data(raw_event)

          buffer.each do |d|
            splited_data = d.split(':')

            case splited_data[0]
            when 'event'
              type = splited_data[1].strip
            when 'data'
              data = parse_event_data(d, type)
              events << StreamData.new(type, data[:client_id], data[:data], data[:channel]) unless type.nil? || data[:data].nil?
            end
          end

          events
        rescue StandardError => e
          @config.logger.error("Error during parsing a event: #{e.inspect}")
          []
        end

        private

        def parse_event_data(data, type)
          event_data = JSON.parse(data.sub('data: ', ''))
          client_id = event_data['clientId']&.strip
          channel = event_data['channel']&.strip
          parsed_data = JSON.parse(event_data['data']) unless type == 'error'
          parsed_data = event_data if type == 'error'

          { client_id: client_id, channel: channel, data: parsed_data }
        end

        def read_partial_data(data)
          buffer = ''
          buffer << data
          buffer.chomp!
          buffer.split("\n")
        end
      end
    end
  end
end
