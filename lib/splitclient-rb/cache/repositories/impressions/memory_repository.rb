module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class MemoryRepository

          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          # Store impression data in the selected adapter
          def add(split_name, data)
            @adapter.add_to_queue(feature: split_name, impressions: data)
          rescue ThreadError # queue is full
            if random_sampler.rand(1..1000) <= 2 # log only 0.2 % of the time
              @config.logger.warn("Dropping impressions. Current size is #{@config.impressions_queue_size}. " \
                                  "Consider increasing impressions_queue_size")
            end
          end

          def add_bulk(key, bucketing_key, treatments, time)
            treatments.each do |split_name, treatment|
              add(
                split_name,
                'keyName' => key,
                'bucketingKey' => bucketing_key,
                'treatment' => treatment[:treatment],
                'label' => @config.labels_enabled ? treatment[:label] : nil,
                'changeNumber' => treatment[:change_number],
                'time' => time
              )
            end
          end

          def get_batch
            return [] if @config.impressions_bulk_size == 0
            @adapter.get_batch(@config.impressions_bulk_size).map do |impression|
              impression.update(ip: @config.machine_ip)
            end
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
