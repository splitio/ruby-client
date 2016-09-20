module SplitIoClient
  module Cache
    module Adapters
      class MemoryAdapter < Adapter
        def initialize
          @map = Concurrent::Map.new
        end

        # Map
        def [](key)
          @map[key]
        end

        def []=(key, obj)
          @map[key] = obj
        end

        def initialize_map(key)
          @map[key] = Concurrent::Map.new
        end

        def add_to_map(key, map_key, map_value)
          @map[key].put(map_key, map_value)
        end

        def find_in_map(key, map_key)
          return nil if @map[key].nil?

          @map[key].get(map_key)
        end

        def delete_from_map(key, map_key)
          @map[key].delete(map_key)
        end

        def in_map?(key, map_key)
          return false if @map[key].nil?

          @map[key].key?(map_key)
        end
      end
    end
  end
end
