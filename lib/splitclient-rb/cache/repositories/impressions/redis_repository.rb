# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class RedisRepository < ImpressionsRepository
          EXPIRE_SECONDS = 3600

          def initialize(adapter)
            @adapter = adapter
          end

          def add(matching_key, bucketing_key, split_name, treatment, time)
            add_bulk(matching_key, bucketing_key, { split_name => treatment }, time)
          end

          def add_bulk(matching_key, bucketing_key, treatments, time)
            impressions = treatments.map do |split_name, treatment|
              {
                m: metadata,
                i: impression_data(
                  matching_key,
                  bucketing_key,
                  split_name,
                  treatment,
                  time
                )
              }.to_json
            end

            impressions_list_size = @adapter.add_to_queue(key, impressions)

            # Synchronizer might not be running
            @adapter.expire(key, EXPIRE_SECONDS) if impressions.size == impressions_list_size
          end

          def batch
            @adapter.get_from_queue(key, SplitIoClient.configuration.impressions_bulk_size).map do |e|
              impression = JSON.parse(e, symbolize_names: true)
              impression[:i][:f] = impression[:i][:f].to_sym
              impression
            end
          rescue StandardError => e
            SplitIoClient.configuration.logger.error("Exception while clearing impressions cache: #{e}")
            []
          end

          def key
            @key ||= namespace_key('.impressions')
          end
        end
      end
    end
  end
end
