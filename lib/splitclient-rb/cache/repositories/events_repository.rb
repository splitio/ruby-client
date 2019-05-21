module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards events interface to the selected adapter
      class EventsRepository < Repository
        extend Forwardable
        def_delegators :@repository, :add, :clear

        def initialize(adapter, api_key)
          @repository = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Events::MemoryRepository.new(adapter)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Events::RedisRepository.new(adapter)
          end

          @api_key = api_key
        end

        def post_events
          events_api.post(self.clear)
        rescue StandardError => error
          SplitIoClient.configuration.log_found_exception(__method__.to_s, error)
        end

        protected

        def metadata
          {
            s: "#{SplitIoClient.configuration.language}-#{SplitIoClient.configuration.version}",
            i: SplitIoClient.configuration.machine_ip,
            n: SplitIoClient.configuration.machine_name
          }
        end

        def event(key, traffic_type, event_type, time, value, properties)
          {
            key: key,
            trafficTypeName: traffic_type,
            eventTypeId: event_type,
            value: value,
            timestamp: time,
            properties: properties
          }.reject { |_, v| v.nil? }
        end

        private

        def events_api
          @events_api ||= SplitIoClient::Api::Events.new(@api_key)
        end
      end
    end
  end
end
