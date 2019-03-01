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

          def get_impressions(number_of_impressions = 0)
            @adapter.get_from_queue(key, number_of_impressions).map do |e|
              impression = JSON.parse(e, symbolize_names: true)
              impression[:i][:f] = impression[:i][:f].to_sym
              impression
            end
          rescue StandardError => e
            SplitIoClient.configuration.logger.error("Exception while clearing impressions cache: #{e}")
            []
          end

          def batch
            get_impressions(SplitIoClient.configuration.impressions_bulk_size)
          end

          def clear
            get_impressions
          end

          def key
            @key ||= namespace_key('.impressions')
          end
        end
      end
    end
  end
end
