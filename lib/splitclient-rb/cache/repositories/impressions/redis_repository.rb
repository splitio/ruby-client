# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class RedisRepository < ImpressionsRepository
          EXPIRE_SECONDS = 3600

          def initialize(config)
            @config = config
            @adapter = @config.impressions_adapter
          end

          def add_bulk(impressions)
            impressions_json = impressions.map do |impression|
              impression.to_json
            end

            impressions_list_size = @adapter.add_to_queue(key, impressions_json)

            # Synchronizer might not be running
            @adapter.expire(key, EXPIRE_SECONDS) if impressions_json.size == impressions_list_size
          rescue StandardError => e
            @config.logger.error("Exception while add_bulk: #{e}")
          end

          def get_impressions(number_of_impressions = 0)
            @adapter.get_from_queue(key, number_of_impressions).map do |e|
              impression = JSON.parse(e, symbolize_names: true)
              impression[:i][:f] = impression[:i][:f].to_sym
              impression
            end
          rescue StandardError => e
            @config.logger.error("Exception while clearing impressions cache: #{e}")
            []
          end

          def batch
            get_impressions(@config.impressions_bulk_size)
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
