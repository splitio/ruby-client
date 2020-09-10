# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards impressions interface to the selected adapter
      class ImpressionsRepository < Repository
        extend Forwardable
        def_delegators :@repository, :add, :add_bulk, :batch, :clear, :empty?, :add_bulk_v2

        def initialize(config)
          super(config)
          @repository = case @config.impressions_adapter.class.to_s
                     when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
                       Repositories::Impressions::MemoryRepository.new(@config)
                     when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                       Repositories::Impressions::RedisRepository.new(@config)
                     end
        end
      end
    end
  end
end
