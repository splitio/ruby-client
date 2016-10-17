require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        def initialize(adapter)
          @adapter = adapter

          @adapter.set_string(namespace_key('last_change'), '-1')
          @adapter.initialize_map(namespace_key('splits'))
          @adapter.initialize_map(namespace_key('used_segment_names'))
        end

        def add_split(split)
          split_without_name = split.select { |k, _| k != :name }

          @adapter.add_to_map(namespace_key('splits'), split[:name], split_without_name.to_json)
        end

        def remove_split(name)
          @adapter.add_to_map(namespace_key('splits'), name, nil)
        end

        def get_split(name)
          split = @adapter.find_in_map(namespace_key('splits'), name)

          JSON.parse(split, symbolize_names: true)
        end

        def splits
          splits_hash = {}
          splits_map = @adapter.get_map(namespace_key('splits'))

          splits_map.each_key do |key|
            splits_hash[key] = JSON.parse(splits_map[key], symbolize_names: true)
          end

          splits_hash
        end

        def set_change_number(since)
          @adapter.set_string(namespace_key('last_change'), since)
        end

        def get_change_number
          @adapter.string(namespace_key('last_change'))
        end

        def set_segment_names(names)
          return if names.nil? || names.empty?

          names.each do |name|
            @adapter.add_to_map(namespace_key('used_segment_names'), name, 1)
          end
        end

        private

        def namespace_key(key)
          "splits_repository_#{key}"
        end
      end
    end
  end
end
