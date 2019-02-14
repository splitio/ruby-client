module SplitIoClient
  module Cache
    module Repositories
      module Events
        class RedisRepository < EventsRepository
          EVENTS_SLICE = 100

          def initialize(adapter)
            @adapter = adapter
          end

          def add(key, traffic_type, event_type, time, value)
            @adapter.add_to_queue(
              namespace_key('.events'),
              { m: metadata, e: event(key, traffic_type, event_type, time, value) }.to_json,
            )
          end

          def get_events(number_of_events = 0)
            @adapter.get_from_queue(namespace_key('.events'), number_of_events).map do |e|
              JSON.parse(e, symbolize_names: true)
            end
          rescue StandardError => e
            SplitIoClient.configuration.logger.error("Exception while clearing events cache: #{e}")
            []
          end

          def batch
            get_events(EVENTS_SLICE)
          end

          def clear
            get_events
          end

        end
      end
    end
  end
end
