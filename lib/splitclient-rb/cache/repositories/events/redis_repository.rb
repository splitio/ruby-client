module SplitIoClient
  module Cache
    module Repositories
      module Events
        class RedisRepository < Repository
          EVENTS_SLICE = 100

          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          def add(key, traffic_type, event_type, time, value)
            @adapter.add_to_queue(
              namespace_key('events'),
              { m: metadata, e: event }.to_json,
              @config.events_queue_size
            )
          end

          def clear
            @adapter.get_from_queue(impressions_metrics_key('events'), EVENTS_SLICE)
          end

          private

          def metadata
            {
              s: "#{@config.language}-#{@config.version}",
              i: @config.machine_ip,
              n:
            }
          end

          def event(key, traffic_type, event_type, time, value)
            {
              key: key,
              'trafficTypeName' => traffic_type,
              'eventTypeId' => event_type,
              'value' => value,
              'timestamp' => time
            }.reject { |_, v| v.nil? }
          end
        end
      end
    end
  end
end
