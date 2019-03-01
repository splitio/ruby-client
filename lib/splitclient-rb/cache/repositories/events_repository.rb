module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards events interface to the selected adapter
      class EventsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :clear, :batch

        def initialize(adapter)
          @adapter = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Events::MemoryRepository.new(adapter)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Events::RedisRepository.new(adapter)
          end
        end

        protected

        def metadata
          {
            s: "#{SplitIoClient.configuration.language}-#{SplitIoClient.configuration.version}",
            i: SplitIoClient.configuration.machine_ip,
            n: SplitIoClient.configuration.machine_name
          }
        end

        def event(key, traffic_type, event_type, time, value)
          {
            key: key,
            trafficTypeName: traffic_type,
            eventTypeId: event_type,
            value: value,
            timestamp: time
          }.reject { |_, v| v.nil? }
        end
      end
    end
  end
end
