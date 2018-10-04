module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards impressions interface to the selected adapter
      class ImpressionsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :add_bulk, :get_batch, :empty?

        def initialize(adapter)
          @adapter = case adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Impressions::MemoryRepository.new(adapter)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Impressions::RedisRepository.new(adapter)
          end
        end
      end
    end
  end
end
