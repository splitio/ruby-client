module SplitIoClient
  module Cache
    module Repositories
      module Metrics
        class RedisRepository < Repository
          def initialize(adapter = nil, config)
            @config = config
            @adapter = adapter
          end

          def add_count(counter, delta)
            prefixed_name = namespace_key("count.#{counter}")
            counts = @adapter.find_strings_by_prefix(prefixed_name)

            @adapter.inc(prefixed_name, delta)
          end

          def add_latency(operation, time_in_ms, binary_search)
            prefixed_name = namespace_key("latency.#{operation}")
            latencies = @adapter.find_strings_by_prefix(prefixed_name)

            if operation == 'sdk.get_treatment'
              @adapter.inc("#{prefixed_name}.#{binary_search.add_latency_millis(time_in_ms, true)}")
              return
            end

            @adapter.append_to_string(prefixed_name, "#{time_in_ms},")
          end

          def add_gauge(gauge, value)
            # TODO
          end

          def counts
            keys = @adapter.find_strings_by_prefix(namespace_key('count'))

            return [] if keys.empty?

            @adapter.multiple_strings(keys).map do |name, data|
              [name.gsub(namespace_key('count.'), ''), data]
            end.to_h
          end

          def latencies
            collected_latencies = {}
            latencies_array = Array.new(BinarySearchLatencyTracker::BUCKETS.length, 0)
            keys = @adapter.find_strings_by_prefix(namespace_key('latency'))

            return [] if keys.empty?

            found_latencies = @adapter.multiple_strings(keys).map do |name, data|
              [name.gsub(namespace_key('latency.'), ''), data]
            end.to_h

            found_latencies.each do |key, value|
              if key.start_with?('sdk.get_treatment')
                index = key.gsub('sdk.get_treatment.', '').to_i
                latencies_array[index] = value.to_i

                next
              end

              collected_latencies[key] = value.split(',').map(&:to_f)
            end

            collected_latencies['sdk.get_treatment'] = latencies_array

            collected_latencies
          end

          def gauges
            # TODO
          end

          def clear_counts
            keys = @adapter.find_strings_by_prefix(namespace_key('count'))
            @adapter.delete(keys)
          end

          def clear_latencies
            keys = @adapter.find_strings_by_prefix(namespace_key('latency'))
            @adapter.delete(keys)
          end

          def clear_gauges
            # TODO
          end
        end
      end
    end
  end
end
