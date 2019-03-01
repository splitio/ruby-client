require 'lru_redux'

module SplitIoClient
  module Cache
    module Adapters
      class CacheAdapter
        extend Forwardable
        def_delegators :@adapter, :initialize_set, :set_bool, :pipelined

        def initialize(adapter)
          @cache = LruRedux::TTL::ThreadSafeCache.new(SplitIoClient.configuration.max_cache_size, SplitIoClient.configuration.cache_ttl)
          @adapter = adapter
        end

        def delete(key)
          @cache.delete(key)
          @adapter.delete(key)
        end

        def clear(namespace_key)
          @cache.clear
        end

        def string(key)
          value = get(key)
          return value if value
          value = @adapter.string(key)
          add(key, value)
          value
        end

        def set_string(key, value)
          add(key, value)
          @adapter.set_string(key, value)
        end

        def multiple_strings(keys)
          cached_values = keys.each_with_object({}) do |key, memo|
             memo[key] = get(key)
          end

          non_cached_keys = []
          cached_values.delete_if{ |k,v| v.nil? ? non_cached_keys << k : false }

          if non_cached_keys.any?
            new_values = @adapter.multiple_strings(non_cached_keys)

            new_values.keys.each do |key, value|
              add(key, value)
            end

            cached_values.merge!(new_values)
          end

          cached_values
        end

        def find_strings_by_prefix(prefix)
          @adapter.find_strings_by_prefix(prefix)
        end

        def exists?(key)
          cached_value = get(key)
          if cached_value.nil?
            @adapter.exists?(key)
          else
            true
          end
        end

        def add_to_set(key, values)
          if values.is_a? Array
            values.each { |value| add_to_map(key, value, 1) }
          else
            add_to_map(key, values, 1)
          end
          @adapter.add_to_set(key, values)
        end

        def in_set?(key, field)
          cached_value = get(key)
          if cached_value.nil?
            return @adapter.in_set?(key, field)
          end
          cached_value.key?(field)
        end

        def get_set(key)
          cached_value = get(key)
          if cached_value.nil?
            return @adapter.get_set(key)
          end
          cached_value.keys
        end

        def delete_from_set(key, fields)
          cached_value = get(key)
          if cached_value
            if fields.is_a? Array
              fields.each { |field| cached_value.delete(field) }
            else
              cached_value.delete(fields)
            end
          end

          @adapter.delete_from_set(key, fields)
        end

        def initialize_map(key)
          @cache[key] = Concurrent::Map.new
        end

        private

        def add_to_map(key, field, value)
          initialize_map(key) unless get(key)
          get(key).put(field.to_s, value.to_s)
        end

        def add(key, value)
          @cache[key] = value.to_s unless value.nil?
        end

        def get(key)
          @cache[key]
        end
      end
    end
  end
end
