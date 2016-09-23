module SplitIoClient
  module Cache
    module Repositories
      class SegmentsRepository < Repository
        def add_to_segment(segment)
          name = segment[:name]

          @adapter.initialize_map(namespace_key("segments:#{name}")) if @adapter[namespace_key("segments:#{name}")].nil?

          add_keys(name, segment[:added])
          remove_keys(name, segment[:removed])
        end

        def get_segment_keys(name)
          @adapter[namespace_key("segments:#{name}")]
        end

        def in_segment?(name, key)
          @adapter.in_map?(namespace_key("segments:#{name}"), key)
        end

        def used_segment_names
          @adapter['splits_repository_used_segment_names']
        end

        def set_change_number(name, last_change)
          @adapter.initialize_map(namespace_key('changes')) if @adapter[namespace_key('changes')].nil?

          @adapter.add_to_map(namespace_key('changes'), name, last_change)
        end

        def get_change_number(name)
          @adapter.find_in_map(namespace_key('changes'), name) || -1
        end

        private

        def namespace_key(key)
          "segments_repository_#{key}"
        end

        def add_keys(name, keys)
          keys.each { |key| @adapter.add_to_map(namespace_key("segments:#{name}"), key, 1) }
        end

        def remove_keys(name, keys)
          keys.each { |key| @adapter.delete_from_map(namespace_key("segments:#{name}"), key) }
        end
      end
    end
  end
end
