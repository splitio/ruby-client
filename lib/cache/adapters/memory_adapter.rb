module SplitIoClient
  module Cache
    module Adapters
      class MemoryAdapter < Adapter
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
        def initialize_set(key)
          @hash[key] = Set.new
        end

        def add_to_set(key, data)
          data.is_a?(Enumerable) ? @hash[key].merge(data) : @hash[key].add(data)
        end

        def remove_from_set(key, data)
          data.is_a?(Enumerable) ? @hash[key].subtract(data) : @hash[key].delete(data)
        end

        def in_set?(key, value)
          @hash[key].include?(value)
        end

        # Hash
        def initialize_hash(key)
          @hash[key] = {}
        end

        def add_to_hash(key, hash_key, hash_value)
          @hash[key].store(hash_key, hash_value)
        end

        def find_in_hash(key, hash_key)
          @hash.fetch(key, {})[hash_key]
        end

        def remove_from_hash(key, hash_keys)
          if hash_keys.is_a?(Enumerable)
            @hash[key].delete_if { |k, _| hash_keys.include?(k) }
          else
            @hash[key].delete(hash_keys)
          end
        end
      end
    end
  end
end
