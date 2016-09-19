module SplitIoClient
  module Cache
    module Repositories
      class SegmentsRepository < Repository
        def add_to_segment(segment)
          name = segment[:name]

          @adapter.initialize_set(namespace_key("segments:#{name}")) if @adapter[namespace_key("segments:#{name}")].nil?

          @adapter.add_to_set(namespace_key("segments:#{name}"), segment[:added])
          @adapter.remove_from_set(namespace_key("segments:#{name}"), segment[:removed])
        end

        def get_segment_keys(name)
          @adapter[namespace_key("segments:#{name}")]
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

        # Non-atomic
        def set_change_number(name, last_change)
          @adapter.initialize_hash(namespace_key('changes')) if @adapter[namespace_key('changes')].nil?

          @adapter.add_to_hash(namespace_key('changes'), name, last_change)
        end

        # Non-atomic
        def get_change_number(name)
          @adapter.find_in_hash(namespace_key('changes'), name) || -1
        end

        private

        def namespace_key(key)
          "segments_repository_#{key}"
        end
      end
    end
  end
end
