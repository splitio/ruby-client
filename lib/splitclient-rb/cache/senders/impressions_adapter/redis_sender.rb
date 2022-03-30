# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class RedisImpressionsSender < ImpressionsSenderAdapter
        def initialize(config)
          @config = config
          @adapter = @config.impressions_adapter
        end

        def record_uniques_key(uniques)
          # TODO: implementation
        end

        def record_impressions_count(impressions_count)
          @adapter.redis.pipelined do |pipeline|
            impressions_count.each do |key, value|
              pipeline.hincrby(impressions_count_key, key, value)
            end
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        private

        def impressions_count_key
          "#{@config.redis_namespace}.impressions.count"
        end
      end
    end
  end
end
