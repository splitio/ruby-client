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
              impressions_metrics_key("impressions.#{split_name}"),
              data.to_json
            )
          end

          # Store impressions in bulk
          def add_bulk(key, bucketing_key, treatments, time)
            @adapter.redis.pipelined do
              treatments.each_slice(@config.impressions_slice_size) do |treatments_slice|
                treatments_slice.each do |split_name, treatment|
                  add(split_name,
                      'keyName' => key,
                      'bucketingKey' => bucketing_key,
                      'treatment' => treatment[:treatment],
                      'label' => @config.labels_enabled ? treatment[:label] : nil,
                      'changeNumber' => treatment[:change_number],
                      'time' => time)
                end
              end
            end
          end

          # Get random impressions from redis in batches of size @config.impressions_queue_size,
          # delete fetched impressions afterwards
          def clear
            impressions = impression_keys.each_with_object([]) do |key, memo|
              ip = key.split('/')[-2] # 'prefix/sdk_lang/ip/impressions.name' -> ip
              if ip.nil?
                @config.logger.warn("Impressions IP parse error for key: #{key}")
                next
              end
              split_name = key.split('.').last
              members = @adapter.random_set_elements(key, @config.impressions_queue_size)
              members.each do |impression|
                parsed_impression = JSON.parse(impression)

                memo << {
                  feature: split_name,
                  impressions: parsed_impression,
                  ip: ip
                }
              end

              @adapter.delete_from_set(key, members)
            end

            impressions
          rescue StandardError => e
            @config.logger.error("Exception while clearing impressions cache: #{e}")
          end

          private

          # Get all sets by prefix
          def impression_keys
            @adapter.find_sets_by_prefix("#{@config.redis_namespace}/*/impressions.*")
          rescue StandardError => e
            @config.logger.error("Exception while fetching impression_keys: #{e}")
          end
        end
      end
    end
  end
end
