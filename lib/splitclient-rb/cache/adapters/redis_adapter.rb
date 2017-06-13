require 'json'

module SplitIoClient
  module Cache
    module Adapters
      # Redis adapter used to provide interface to Redis
      class RedisAdapter
        SCAN_SLICE = 5000

        attr_reader :redis

        def initialize(redis_url)
          connection = redis_url.is_a?(Hash) ? redis_url : { url: redis_url }

          @redis = Redis.new(connection)
        end

        # Map
        def initialize_map(key)
          # No need to initialize hash/map in Redis
        end

        def add_to_map(key, field, value)
          @redis.hset(key, field, value)
        end

        def find_in_map(key, field)
          @redis.hget(key, field)
        end

        def delete_from_map(key, field)
          @redis.hdel(key, field)
        end

        def in_map?(key, field)
          @redis.hexists(key, field)
        end

        def map_keys(key)
          @redis.hkeys(key)
        end

        def get_map(key)
          @redis.hgetall(key)
        end

        # String
        def string(key)
          @redis.get(key)
        end

        def set_string(key, str)
          @redis.set(key, str)
        end

        def find_strings_by_prefix(prefix)
          memo = { items: [], cursor: 0 }

          loop do
            memo[:cursor], items = @redis.scan(memo[:cursor], match: "#{prefix}*", count: SCAN_SLICE)

            memo[:items].push(*items)

            break if memo[:cursor] == '0'
          end

          memo[:items]
        end

        def multiple_strings(keys)
          Hash[keys.zip(@redis.mget(keys))]
        end

        def append_to_string(key, val)
          @redis.append(key, val)
        end

        # Bool
        def set_bool(key, val)
          @redis.set(key, val.to_s)
        end

        def bool(key)
          @redis.get(key) == 'true'
        end

        # Set
        alias_method :initialize_set, :initialize_map
        alias_method :find_sets_by_prefix, :find_strings_by_prefix

        def add_to_set(key, val)
          @redis.sadd(key, val)
        end

        def delete_from_set(key, val)
          @redis.srem(key, val)
        end

        def get_set(key)
          @redis.smembers(key)
        end

        def in_set?(key, val)
          @redis.sismember(key, val)
        end

        def get_all_from_set(key)
          @redis.smembers(key)
        end

        def union_sets(set_keys)
          return [] if set_keys == []

          @redis.sunion(set_keys)
        end

        def random_set_elements(key, count)
          @redis.srandmember(key, count)
        end

        # General
        def exists?(key)
          @redis.exists(key)
        end

        def delete(key)
          return nil if key == []

          @redis.del(key)
        end

        def inc(key, inc = 1)
          @redis.incrby(key, inc)
        end

        def pipelined(&block)
          @redis.pipelined do
            block.call
          end
        end

        def clear(prefix)
          keys = @redis.keys("#{prefix}*")

          keys.map { |key| @redis.del(key) }
        end
      end
    end
  end
end
