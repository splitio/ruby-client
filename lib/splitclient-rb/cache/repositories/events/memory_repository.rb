module SplitIoClient
  module Cache
    module Repositories
      module Events
        class MemoryRepository < EventsRepository
          EVENTS_MAX_SIZE_BYTES = 5242880

          def initialize(config, telemetry_runtime_producer)
            @config = config
            @adapter = @config.events_adapter
            @size = 0
            @telemetry_runtime_producer = telemetry_runtime_producer
          end

          def add(key, traffic_type, event_type, time, value, properties, event_size)
            @adapter.add_to_queue(m: metadata, e: event(key, traffic_type, event_type, time, value, properties))
            @size += event_size

            post_events if @size >= EVENTS_MAX_SIZE_BYTES || @adapter.length == @config.events_queue_size

            @telemetry_runtime_producer.record_events_stats(Telemetry::Domain::Constants::EVENTS_QUEUED, 1)
          rescue StandardError => e
            @config.log_found_exception(__method__.to_s, e)
            @telemetry_runtime_producer.record_events_stats(Telemetry::Domain::Constants::EVENTS_DROPPED, 1)
          end

          def clear
            @size = 0
            @adapter.clear
          end

          def batch
            return [] if @config.events_queue_size.zero?

            @adapter.get_batch(@config.events_queue_size)
          end
        end
      end
    end
  end
end
