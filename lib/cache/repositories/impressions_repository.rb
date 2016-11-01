module SplitIoClient
  module Cache
    module Repositories
      class ImpressionsRepository < Repository
        def initialize(adapter)
          @adapter = adapter
        end

        def add(split_name, data)
          @adapter.add_to_set(namespace_key(split_name), data.to_json)
        end

        def clear
          impression_keys = @adapter.find_sets_by_prefix(namespace_key(''))
          impressions = @adapter.union_sets(impression_keys)

          @adapter.delete(impression_keys)

          if impressions.first.is_a? String
            impressions.map { |impression| JSON.parse(impression) }
          else
            impressions
          end
        end

        private

        def namespace_key(key)
          "impressions.#{super(key)}"
        end
      end
    end
  end
end
