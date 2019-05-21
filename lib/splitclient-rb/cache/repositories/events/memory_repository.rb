module SplitIoClient
  module Cache
    module Repositories
      module Events
        class MemoryRepository < EventsRepository
          EVENTS_MAX_SIZE_BYTES = 5242880

          def initialize(adapter)
            @adapter = adapter
            @size = 0
          end

          def add(key, traffic_type, event_type, time, value, properties, event_size)
            @adapter.add_to_queue(m: metadata, e: event(key, traffic_type, event_type, time, value, properties))
            @size += event_size

            post_events if @size >= EVENTS_MAX_SIZE_BYTES || @adapter.length == SplitIoClient.configuration.events_queue_size

            rescue StandardError => error
              SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
          end

          def clear
            @size = 0
            @adapter.clear
          end
        end
      end
    end
  end
end
