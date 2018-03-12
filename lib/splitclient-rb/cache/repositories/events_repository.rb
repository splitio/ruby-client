require 'forwardable'

module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards events interface to the selected adapter
      class EventsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :clear

        def initialize(adapter, config)
          @config = config
          @adapter = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Events::MemoryRepository.new(adapter, config)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Events::RedisRepository.new(adapter, config)
          end
        end

        protected

        def metadata
          {
            s: "#{@config.language}-#{@config.version}",
            i: @config.machine_ip,
            n: @config.machine_name
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
