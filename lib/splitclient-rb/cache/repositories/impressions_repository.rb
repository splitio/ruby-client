# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards impressions interface to the selected adapter
      class ImpressionsRepository < Repository
        extend Forwardable
        def_delegators :@adapter, :add, :add_bulk, :batch, :clear, :empty?

        def initialize(adapter)
          @adapter = case adapter.class.to_s
                     when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
                       Repositories::Impressions::MemoryRepository.new(adapter)
                     when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                       Repositories::Impressions::RedisRepository.new(adapter)
                     end
        end

        protected

        def impression_data(matching_key, bucketing_key, split_name, treatment, timestamp)
          {
            k: matching_key,
            b: bucketing_key,
            f: split_name,
            t: treatment[:treatment],
            r: applied_rule(treatment[:label]),
            c: treatment[:change_number],
            m: timestamp
          }
        end

        def metadata
          {
            s: "#{SplitIoClient.configuration.language}-#{SplitIoClient.configuration.version}",
            i: SplitIoClient.configuration.machine_ip,
            n: SplitIoClient.configuration.machine_name
          }
        end

        def applied_rule(label)
          SplitIoClient.configuration.labels_enabled ? label : nil
        end
      end
    end
  end
end
