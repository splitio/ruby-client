module SplitIoClient
  module Cache
    module Repositories
      class SegmentRepository
        def initialize(adapter)
          @adapter = adapter

          @adapter[namespace_key('since')] = -1
          @adapter[namespace_key('till')] = nil
          @adapter[namespace_key('names')] = Set.new
          @adapter[namespace_key('keys')] = Set.new
          @adapter[namespace_key('segments')] = {}
        end

        def []=(key, obj)
          @adapter[namespace_key(key)] = obj
        end

        def [](key)
          @adapter[namespace_key(key)]
        end

        def add(segment)
          segment_without_name = segment.select { |k, _| k != :name }

          @adapter.add_to_hash(namespace_key('segments'), segment[:name], segment_without_name)
          @adapter.add_to_set(namespace_key('names'), segment[:name])
          @adapter.add_to_set(namespace_key('keys'), segment[:added])
          @adapter.remove_from_set(namespace_key('keys'), segment[:removed])
        end

        def find(name)
          @adapter.find_in_hash(namespace_key('segments'), name)
        end

        def used_segment_names
          @adapter['used_segment_names']
        end

        private

        def namespace_key(key)
          "segments_repository_#{key}"
        end
      end
    end
  end
end
