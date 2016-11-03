module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class RedisRepository < Repository
          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          def add(split_name, data)
            @adapter.add_to_set(
              namespace_key(split_name), data.merge(split_name: split_name).to_json
            )
          end

          def clear(impressions_enumerator = nil)
            impressions = impression_keys.each_with_object([]) do |key, memo|
              @adapter.random_set_elements(key, @config.impressions_queue_size).each do |impression|
                parsed_impression = JSON.parse(impression)

                memo << {
                  feature: parsed_impression['split_name'],
                  impressions: parsed_impression.reject { |k, _| k == 'split_name' }
                }

                @adapter.delete_from_set(key, impression)
              end
            end

            impressions
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
