module SplitIoClient
  module Cache
    module Repositories
      module Events
        class MemoryRepository < EventsRepository
          EVENTS_SLICE = 100

          def initialize(adapter)
            @adapter = adapter
          end

          def add(key, traffic_type, event_type, time, value)
            @adapter.add_to_queue(m: metadata, e: event(key, traffic_type, event_type, time, value))
          rescue ThreadError # queue is full
            if SplitIoClient.configuration.debug_enabled
              SplitIoClient.configuration.logger.warn("Dropping events. Current size is #{SplitIoClient.configuration.events_queue_size}. " \
                                  "Consider increasing events_queue_size")
            end
            @adapter.clear
          end

          def clear
            @adapter.clear
          end
        end
      end
    end
  end
end
