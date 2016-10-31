require 'concurrent'

module SplitIoClient
  module Cache
    module Adapters
      class MemoryAdapter
        def initialize
          @map = Concurrent::Map.new
        end

        # Map
        def initialize_map(key)
          @map[key] = Concurrent::Map.new
        end

        def add_to_map(key, field, value)
          @map[key].put(field, value)
        end

        def find_in_map(key, field)
          return nil if @map[key].nil?

          @map[key].get(field)
        end

        def delete_from_map(key, fields)
          if fields.is_a? Array
            fields.each { |field| @map[key].delete(field) }
          else
            @map[key].delete(field)
          end
        end

        def in_map?(key, field)
          return false if @map[key].nil?

          @map[key].key?(field)
        end

        def map_keys(key)
          @map[key].keys
        end

        def get_map(key)
          @map[key]
        end

        # String
        def string(key)
          @map[key]
        end

        def set_string(key, str)
          @map[key] = str
        end

        def find_strings_by_prefix(prefix)
          @map.keys.select { |str| str.start_with? prefix }
        end

        def multiple_strings(keys)
          keys.each_with_object({}) do |key, memo|
            memo[key] = string(key)
          end
        end

        # Bool
        def set_bool(key, val)
          @map[key] = val
        end

        def bool(key)
          @map[key]
        end

        # Set
        alias_method :initialize_set, :initialize_map
        alias_method :get_set, :map_keys
        alias_method :delete_from_set, :delete_from_map
        alias_method :in_set?, :in_map?

        def add_to_set(key, values)
          if values.is_a? Array
            values.each { |value| add_to_map(key, value, 1) }
          else
            add_to_map(key, values, 1)
          end
        end

        # General
        def exists?(key)
          !@map[key].nil?
        end

        def delete(key)
          @map.delete(key)
        end
      end
    end
  end
end
