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

          def clear
            @adapter.get_from_queue(namespace_key('.events'), EVENTS_SLICE).map do |e|
              JSON.parse(e, symbolize_names: true)
            end
          end
        end
      end
    end
  end
end
