module SplitIoClient
  module Cache
    module Repositories
      module Events
        class RedisRepository < EventsRepository

          def initialize(adapter)
            @adapter = adapter
          end

          def add(key, traffic_type, event_type, time, value, properties, size)
            @adapter.add_to_queue(
              namespace_key('.events'),
              { m: metadata, e: event(key, traffic_type, event_type, time, value, properties) }.to_json
            )
          end

          def clear
            @adapter.get_from_queue(namespace_key('.events'), 0).map do |e|
              JSON.parse(e, symbolize_names: true)
            end
          rescue StandardError => e
            SplitIoClient.configuration.logger.error("Exception while clearing events cache: #{e}")
            []
          end
        end
      end
    end
  end
end
