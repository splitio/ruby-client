module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        def initialize(adapter)
          @adapter = adapter

          @adapter[namespace_key('since')] = -1
          @adapter[namespace_key('splits')] = {}
        end

        def add(split)
          split_without_name = split.select { |k, _| k != :name }

          @adapter.add_to_hash(namespace_key('splits'), split[:name], split_without_name)
        end

        def find(name)
          @adapter.find_in_hash(namespace_key('splits'), name)
        end

        private

        def namespace_key(key)
          "splits_repository_#{key}"
        end
      end
    end
  end
end
