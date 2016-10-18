require 'redis'
require 'json'

module SplitIoClient
  module Cache
    module Adapters
      class RedisAdapter
        def initialize
          # TODO: Add Redis config
          @redis = Redis.new
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

        # Bool
        def set_bool(key, val)
          @redis.set(key, val.to_s)
        end

        def bool(key)
          @redis.get(key) == 'true'
        end

        # Set
        def add_to_set(key, val)
          @redis.sadd(key, val)
        end

        def get_set(key)
          @redis.smembers(key)
        end

        # General
        def exists?(key)
          @redis.exists(key)
        end
      end
    end
  end
end
