module SplitIoClient
  module Cache
    module Repositories
      module Events
        class MemoryRepository < EventsRepository
          EVENTS_SLICE = 100

          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          def add(key, traffic_type, event_type, time, value)
            @adapter.add_to_queue(m: metadata, e: event(key, traffic_type, event_type, time, value))
          rescue ThreadError # queue is full
            if @config.debug_enabled
              @config.logger.warn("Dropping events. Current size is #{@config.events_queue_size}. " \
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
