# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class UniqueKeysSenderAdapter
        extend Forwardable
        def_delegators :@sender, :record_uniques_key, :record_impressions_count

        def initialize(config)
          @sender = case config.telemetry_adapter.class.to_s
                    when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                      Cache::Senders::MemoryUniqueKeysSender.new(config)
                    else
                      Cache::Senders::RedisUniqueKeysSender.new(config)
                    end
        end
      end
    end
  end
end
