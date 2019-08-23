module SplitIoClient
  module Cache
    module Repositories
      module Metrics
        class RedisRepository < Repository
          def initialize(config)
            @config = config
            @adapter = config.metrics_adapter
          end

          def add_count(counter, delta)
            prefixed_name = impressions_metrics_key("count.#{counter}")
            counts = @adapter.find_strings_by_prefix(prefixed_name)

            @adapter.inc(prefixed_name, delta)
          end

          def add_latency(operation, time_in_ms, binary_search)
            prefixed_name = impressions_metrics_key("latency.#{operation}")

            @adapter.inc("#{prefixed_name}.bucket.#{binary_search.add_latency_millis(time_in_ms, true)}")
          end

          def add_gauge(gauge, value)
            # TODO
          end

          def counts
            keys = @adapter.find_strings_by_prefix(impressions_metrics_key("count"))

            return [] if keys.empty?

            @adapter.multiple_strings(keys).map do |name, data|
              [name.gsub(impressions_metrics_key('count.'), ''), data]
            end.to_h
          end

          def latencies
            keys = @adapter.find_strings_by_prefix(impressions_metrics_key('latency'))
            return [] if keys.empty?

            collected_latencies = collect_latencies(keys)

            collected_latencies.keys.each_with_object({}) do |operation, latencies|
              operation_latencies = Array.new(BinarySearchLatencyTracker::BUCKETS.length, 0)
              collected_latencies[operation].each do |bucket, value|
                operation_latencies[bucket.to_i] = value.to_i
              end

              latencies[operation] = operation_latencies
            end
          end

          def gauges
            # TODO
          end

          def clear_counts
            keys = @adapter.find_strings_by_prefix(impressions_metrics_key('count'))
            @adapter.delete(keys)
          end

          def clear_latencies
            keys = @adapter.find_strings_by_prefix(impressions_metrics_key('latency'))
            @adapter.delete(keys)
          end

          # introduced to fix incorrect latencies
          def fix_latencies
            keys =[]

            23.times do |index|
              keys.concat @adapter.find_strings_by_pattern(latencies_to_be_deleted_key_pattern_prefix("sdk.get_treatment.#{index}"))
            end

            keys.concat @adapter.find_strings_by_pattern(latencies_to_be_deleted_key_pattern_prefix('sdk.get_treatments'))
            keys.concat @adapter.find_strings_by_pattern(latencies_to_be_deleted_key_pattern_prefix('sdk.get_treatment_with_config'))
            keys.concat @adapter.find_strings_by_pattern(latencies_to_be_deleted_key_pattern_prefix('sdk.get_treatments_with_config'))

            keys.concat @adapter.find_strings_by_pattern(latencies_to_be_deleted_key_pattern_prefix('*.time'))

            @config.logger.info("Found incorrect latency keys, deleting. Keys: #{keys}") unless keys.size == 0

            keys.each_slice(500) do |chunk|
              @adapter.pipelined do
                chunk.each do |key|
                  @adapter.delete key
                end
              end
            end
          end

          def latencies_to_be_deleted_key_pattern_prefix(key)
            "#{@config.redis_namespace}/#{@config.language}-*/latency.#{key}"
          end

          def clear_gauges
            # TODO
          end

          def clear
            clear_counts
            clear_latencies
            clear_gauges
          end

          private

          def find_latencies(keys)
            @adapter.multiple_strings(keys).map do |name, data|
              [name.gsub(impressions_metrics_key('latency.'), ''), data]
            end.to_h
          end

          def collect_latencies(keys)
            find_latencies(keys).each_with_object({}) do |(key, value), collected_latencies|
              operation, bucket = key.split('.bucket.')
              collected_latencies[operation] = {} unless collected_latencies[operation]
              collected_latencies[operation].merge!({bucket => value})
            end
          end
        end
      end
    end
  end
end
