# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Senders
      class RedisImpressionsSender < ImpressionsSenderAdapter
        EXPIRE_SECONDS = 3600

        def initialize(config)
          @config = config
          @adapter = @config.impressions_adapter
        end

        def record_uniques_key(uniques)
          return if uniques.nil? || uniques.empty?

          size = @adapter.add_to_queue(unique_keys_key, uniques_formatter(uniques))

          @adapter.expire(unique_keys_key, EXPIRE_SECONDS) if uniques.length == size
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def record_impressions_count(impressions_count)
          return if impressions_count.nil? || impressions_count.empty?

          result = @adapter.redis.pipelined do |pipeline|
            impressions_count.each do |key, value|
              pipeline.hincrby(impressions_count_key, key, value)
            end
          end

          expire_impressions_count_key(impressions_count, result)
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        private

        def expire_impressions_count_key(impressions_count, pipeline_result)
          total_count = impressions_count.sum { |_, value| value }
          hlen = pipeline_result.last

          @adapter.expire(impressions_count_key, EXPIRE_SECONDS) if impressions_count.size == hlen && (pipeline_result.sum - hlen) == total_count
        end

        def uniques_formatter(uniques)
          to_return = []
          uniques.each do |key, value|
            to_return << {
              f: key,
              ks: value.to_a
            }.to_json
          end

          to_return
        end

        def impressions_count_key
          "#{@config.redis_namespace}.impressions.count"
        end

        def unique_keys_key
          "#{@config.redis_namespace}.uniquekeys"
        end
      end
    end
  end
end
