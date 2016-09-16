module SplitIoClient
  module Cache
    module Repositories
      class SplitRepository
        def initialize(adapter)
          @adapter = adapter

          @adapter['since'] = -1
          @adapter['splits'] = []
        end

        def []=(key, obj)
          @adapter[key] = obj
        end

        def [](key)
          @adapter[key]
        end

        def remove(key)
          @adapter.remove(key)
        end

        def add(split)
          stored_splits = self['splits']
          refreshed_splits = stored_splits.reject { |s| s[:name] == split[:name] }

          self['splits'] = refreshed_splits + [split]
        end

        def find(name)
          self['splits'].find { |s| s[:name] == name }
        end
      end
    end
  end
end
