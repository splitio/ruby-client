module SplitIoClient
  module Cache
    module Repositories
      class SegmentsRepository < Repository
        def add_to_segment(name, keys)
          # NOTE: The desired structure here would look like:
          # segments = { 'segment_name' => Set ['segment_key1', 'segment_key2'] }
          # But, since Redis does not support nesting data structures we need to store
          # segment name directly in the name of the Set

          # TODO: Initialize empty set
          @adapter.add_to_set(namespace_key("segments:#{name}"), keys)
        end

        def remove_from_segment(name, keys)
          @adapter.remove_from_set(namespace_key("segments:#{name}"), keys)
        end

        def in_segment?(name, key)
          @adapter.in_set?(namespace_key("segments:#{name}"), key)
        end

        def used_segment_names
          @adapter['splits_repository_used_segment_names']
        end

        def set_change_number(name, last_change)
          # TODO: Initialize empty hash

          @adapter.add_to_hash(namespace_key('changes'), name, last_change)
        end

        def get_change_number(name)
          @adapter.add_to_hash(namespace_key('changes'), name)
        end

        private

        def namespace_key(key)
          "segments_repository_#{key}"
        end
      end
    end
  end
end
