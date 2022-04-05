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
          formatted = uniques_formatter(uniques)

          unless formatted.nil?
            size = @adapter.add_to_queue(unique_keys_key, formatted)
            @adapter.expire(unique_keys_key, EXPIRE_SECONDS) if formatted.size == size
          end
        rescue StandardError => e
          @config.log_found_exception(__method__.to_s, e)
        end

        def record_impressions_count(impressions_count)
          return if impressions_count.nil? || impressions_count.empty?

          size = 0
          res = @adapter.redis.pipelined do |pipeline|
            impressions_count.each do |key, value|
              pipeline.hincrby(impressions_count_key, key, value)
            end
          end
puts res
puts '----'
          @adapter.expire(impressions_count_key, EXPIRE_SECONDS) if impressions_count.size == size
        rescue StandardError => e
          puts e
          @config.log_found_exception(__method__.to_s, e)
        end

        private

        def impressions_count_key
          "#{@config.redis_namespace}.impressions.count"
        end

        def unique_keys_key
          "#{@config.redis_namespace}.uniquekeys"
        end

        def uniques_formatter(uniques)
          return if uniques.empty?

          to_return = []
          uniques.each do |key, value|
            to_return << {
              f: key,
              k: value.to_a
            }
          end

          to_return
        rescue StandardError => error
          @config.log_found_exception(__method__.to_s, error)
          nil
        end
      end
    end
  end
end
