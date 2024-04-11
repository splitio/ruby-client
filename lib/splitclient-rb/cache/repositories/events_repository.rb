module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards events interface to the selected adapter
      class EventsRepository < Repository
        extend Forwardable
        def_delegators :@repository, :add, :clear, :batch

        def initialize(config, api_key, telemetry_runtime_producer, request_decorator)
          super(config)
          @repository = case @config.events_adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Events::MemoryRepository.new(@config, telemetry_runtime_producer)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Events::RedisRepository.new(@config)
          end

          @api_key = api_key
          @telemetry_runtime_producer = telemetry_runtime_producer
          @request_decorator = request_decorator
        end

        def post_events
          events_api.post(self.clear)
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        protected

        def metadata
          {
            s: "#{@config.language}-#{@config.version}",
            i: @config.machine_ip,
            n: @config.machine_name
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
          @events_api ||= SplitIoClient::Api::Events.new(@api_key, @config, @telemetry_runtime_producer, @request_decorator)
        end
      end
    end
  end
end
