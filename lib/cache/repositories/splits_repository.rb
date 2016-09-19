module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        def initialize(adapter)
          @adapter = adapter

          @adapter[namespace_key('last_change')] = -1
          @adapter[namespace_key('splits')] = {}
        end

        def add_split(split)
          split_without_name = split.select { |k, _| k != :name }

          @adapter.add_to_hash(namespace_key('splits'), split[:name], split_without_name)
        end

        def remove_split(name)
          @adapter.add_to_hash(namespace_key('splits'), name, nil)
        end

        def get_split(name)
          @adapter.find_in_hash(namespace_key('splits'), name)
        end

        def set_change_number(since)
          @adapter[namespace_key('last_change')] = since
        end

        def get_change_number
          @adapter[namespace_key('last_change')]
        end

        def set_segment_names(names)
          return if names.nil? || names.empty?

          @adapter[namespace_key('used_segment_names')] = names
        end

        private

        def namespace_key(key)
          "splits_repository_#{key}"
        end
      end
    end
  end
end
