module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class RedisRepository < Repository
          IMPRESSIONS_SLICE = 1000

          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          # Store impression data in Redis
          def add(split_name, data)
            @adapter.add_to_set(
              namespace_key("impressions.#{split_name}"),
              data.merge(split_name: split_name).to_json
            )
          end

          def add_bulk(key, bucketing_key, treatments_with_labels, time)
            @adapter.redis.pipelined do
              treatments_with_labels.each_slice(IMPRESSIONS_SLICE) do |treatments_with_labels_slice|
                treatments_with_labels_slice.each do |split_name, treatment_with_label|
                  add(split_name,
                    'key_name' => key,
                    'bucketing_key' => bucketing_key,
                    'treatment' => treatment_with_label[:treatment],
                    'label' => treatment_with_label[:label],
                    'time' => time
                  )
                end
              end
            end
          end

          # Get random impressions from redis in batches of size @config.impressions_queue_size,
          # delete fetched impressions afterwards
          def clear
            impressions = impression_keys.each_with_object([]) do |key, memo|
              members = @adapter.random_set_elements(key, @config.impressions_queue_size)
              members.each do |impression|
                parsed_impression = JSON.parse(impression)

                memo << {
                  feature: parsed_impression['split_name'],
                  impressions: parsed_impression.reject { |k, _| k == 'split_name' }
                }
              end

              @adapter.delete_from_set(key, members)
            end

            impressions
          end

          private

          # Get all sets by prefix
          def impression_keys
            @adapter.find_sets_by_prefix(namespace_key('impressions.'))
          end
        end
      end
    end
  end
end
