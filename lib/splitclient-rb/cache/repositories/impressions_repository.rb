module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards impressions interface to the selected adapter
      class ImpressionsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :add_bulk, :clear, :empty?

        def initialize(adapter, config)
          @config = config
          @adapter = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Impressions::MemoryRepository.new(adapter, config)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Impressions::RedisRepository.new(adapter, config)
          end
        end
      end
    end
  end
end
