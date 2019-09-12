# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Repositories
      # Repository which forwards impressions interface to the selected adapter
      class ImpressionsRepository < Repository
        extend Forwardable
        def_delegators :@repository, :add, :add_bulk, :batch, :clear, :empty?

        def initialize(config)
          super(config)
          @repository = case @config.impressions_adapter.class.to_s
                     when 'SplitIoClient::Cache::Adapters::MemoryAdapter'
                       Repositories::Impressions::MemoryRepository.new(@config)
                     when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                       Repositories::Impressions::RedisRepository.new(@config)
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
            s: "#{@config.language}-#{@config.version}",
            i: @config.machine_ip,
            n: @config.machine_name
          }
        end

        def applied_rule(label)
          @config.labels_enabled ? label : nil
        end
      end
    end
  end
end
