module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class RedisRepository < Repository
          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          # Store impression data in Redis
          def add(split_name, data)
            @adapter.add_to_set(
              namespace_key("impressions.#{split_name}"), data.merge(split_name: split_name).to_json
            )
          end

          def add_bulk(key, treatments, time)
            @adapter.redis.pipelined do
              treatments.each do |split_name, treatment|
                add(split_name, 'key_name' => key, 'treatment' => treatment, 'time' => time)
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
