module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards events interface to the selected adapter
      class EventsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :add_bulk, :clear, :empty?

        def initialize(adapter, config)
          @config = config
          @adapter = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Events::MemoryRepository.new(adapter, config)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Events::RedisRepository.new(adapter, config)
          end
        end
      end
    end
  end
end
