module SplitIoClient
  module Cache
    module Repositories
      class SegmentsRepository < Repository
        def add_to_segment(segment)
          name = segment[:name]

          @adapter.initialize_set(segment_data(name)) unless @adapter.exists?(segment_data(name))

          add_keys(name, segment[:added])
          remove_keys(name, segment[:removed])
        end

        def get_segment_keys(name)
          @adapter.get_set(segment_data(name))
        end

        def in_segment?(name, key)
          @adapter.in_set?(segment_data(name), key)
        end

        def used_segment_names
          @adapter.get_set(namespace_key('segments.registered'))
        end

        def set_change_number(name, last_change)
          @adapter.set_string(namespace_key("segment.#{name}.till"), last_change)
        end

        def get_change_number(name)
          @adapter.string(namespace_key("segment.#{name}.till")) || -1
        end

        private

        def segment_data(name)
          namespace_key("segmentData.#{name}")
        end

        def add_keys(name, keys)
          keys.each { |key| @adapter.add_to_set(segment_data(name), key) }
        end

        def remove_keys(name, keys)
          keys.each { |key| @adapter.delete_from_set(segment_data(name), key) }
        end
      end
    end
  end
end
