module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards impressions interface to the selected adapter
      class MetricsRepository < Repository
        extend Forwardable
        def_delegators :@repository, :add_count, :add_latency, :add_gauge, :counts, :latencies, :gauges,
                       :clear_counts, :clear_latencies, :clear_gauges, :clear, :fix_latencies

        def initialize(config)
          super(config)
          @repository = case @config.metrics_adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
            Repositories::Metrics::MemoryRepository.new(@config)
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            Repositories::Metrics::RedisRepository.new(@config)
          end
        end

      end
    end
  end
end
