module SplitIoClient
  module Cache
    module Repositories
      module Impressions
        class MemoryRepository
          def initialize(adapter, config)
            @adapter = adapter
            @config = config
          end

          # Store impression data in the memory adapter if choice
          def add(split_name, data)
            @adapter.add_to_queue(feature: split_name, impressions: data)
          rescue ThreadError # queue is full
            if random_sampler.rand(1..1000) <= 2 # log only 0.2 % of the time
              @config.logger.warn("Dropping impressions. Current size is #{@config.impressions_queue_size}. " \
                                  'Consider increasing impressions_queue_size')
            end
          end

          # Store impressions in bulk
          def add_bulk(key, bucketing_key, treatments, time)
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

          # Get everything from the queue and leave it empty
          def clear
            @adapter.clear.map { |impression| impression.update(ip: @config.machine_ip) }
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
