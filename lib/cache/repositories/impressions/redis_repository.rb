module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class RedisRepository < Repository
          def initialize(adapter)
            @adapter = adapter
          end

          def add(split_name, data)
            @adapter.add_to_set(
              namespace_key(split_name), data.merge(split_name: split_name).to_json
            )
          end

          def clear
            impressions = @adapter.union_sets(impression_keys).map { |i| JSON.parse(i) }

            @adapter.delete(impression_keys)

            impressions.each_with_object([]) do |impression, memo|
              memo << {
                feature: impression['split_name'],
                impressions: impression.reject { |k, _| k == 'split_name' }
              }
            end
          end

          def empty?
            impression_keys.size > 0
          end

          private

          def namespace_key(key)
            "SPLITIO.impressions.#{key}"
          end

          def impression_keys
            @adapter.find_sets_by_prefix('SPLITIO.impressions.')
          end
        end
      end
    end
  end
end
