module SplitIoClient
  module Cache
    module Repositories
      class ImpressionsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :clear, :empty?

        def initialize(adapter, config)
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
