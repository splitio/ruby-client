# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class MemoryRepository < ImpressionsRepository
          def initialize(config)
            @config = config
            @adapter = @config.impressions_adapter
          end

          # Store impression data in the selected adapter
          # TODO: remove this
          def add(matching_key, bucketing_key, split_name, treatment, time)
            @adapter.add_to_queue(
              m: metadata,
              i: impression_data(
                matching_key,
                bucketing_key,
                split_name,
                treatment,
                time
              )
            )
          rescue ThreadError # queue is full
            if random_sampler.rand(1..1000) <= 2 # log only 0.2 % of the time
              @config.logger.warn("Dropping impressions. Current size is \
                #{@config.impressions_queue_size}. " \
                'Consider increasing impressions_queue_size')
            end
          end

          # TODO: remove this
          def add_bulk(key, bucketing_key, treatments, time)
            treatments.each do |split_name, treatment|
              add(key, bucketing_key, split_name, treatment, time)
            end
          end

          def add_bulk_v2(impressions)
            puts 'add_bulk_v2'
            impressions.each do |impression|
              @adapter.add_to_queue(impression)
            end
          rescue ThreadError # queue is full
            if random_sampler.rand(1..1000) <= 2 # log only 0.2 % of the time
              @config.logger.warn("Dropping impressions. Current size is \
                #{@config.impressions_queue_size}. " \
                'Consider increasing impressions_queue_size')
            end
          end

          def batch
            return [] if @config.impressions_bulk_size.zero?

            @adapter.get_batch(@config.impressions_bulk_size)
          end

          def clear
            @adapter.clear
          end

          def empty?
            @adapter.empty?
          end

          private

          def random_sampler
            @random_sampler ||= Random.new
          end
        end
      end
    end
  end
end
