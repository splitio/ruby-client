# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class ImpressionsSenderAdapter
        extend Forwardable
        def_delegators :@sender, :record_uniques_key, :record_impressions_count

        def initialize(config, telemetry_api, impressions_api)
          @sender = case config.telemetry_adapter.class.to_s
                    when 'SplitIoClient::Cache::Adapters::RedisAdapter'
                      Cache::Senders::RedisImpressionsSender.new(config)
                    else
                      Cache::Senders::MemoryImpressionsSender.new(config, telemetry_api, impressions_api)
                    end
        end
      end
    end
  end
end
