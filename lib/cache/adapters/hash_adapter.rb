module SplitIoClient
  module Cache
    module Adapters
      # TODO: Use thread-safe data structure
      class HashAdapter < Adapter
        def initialize
          @hash = {}
        end

        def []=(key, obj)
          @hash[key] = obj
        end

        def [](key)
          @hash[key]
        end

        def remove(key)
          @hash.delete(key)
        end

        def key?(key)
          @hash.key?
        end

        # Set
        def add_to_set(key, values)
          @hash[key] << values
        end

        # Hash
        def remove_from_set(key, data)
          data.is_a?(Enumerable) ? @hash[key].subtract(data) : @hash[key].delete(data)
        end

        def add_to_hash(key, hash_key, hash_value)
          @hash[key].store(hash_key, hash_value)
        end

        def find_in_hash(key, hash_key)
          @hash.fetch(key, {})[hash_key]
        end
      end
    end
  end
end
