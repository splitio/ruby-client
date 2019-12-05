module SplitIoClient
  module Cache
    module Repositories
      module Metrics
        class MemoryRepository
          OPERATIONS = %w(sdk.get_treatment sdk.get_treatments sdk.get_treatment_with_config sdk.get_treatments_with_config)

          def initialize(_ = nil, config)
            @counts = []
            @latencies = []
            @gauges = []
            @config = config
          end

          def add_count(counter, delta)
            counter_hash = @counts.find { |c| c[:name] == counter }
            if counter_hash.nil?
              counter_delta = SumAndCount.new
              counter_delta.add_delta(delta)
              @counts << { name: counter, delta: counter_delta }
            else
              counter_hash[:delta].add_delta(delta)
            end
          end

          def add_latency(operation, time_in_ms, binary_search)
            if (OPERATIONS.include?(operation))
              index = binary_search.add_latency_millis(time_in_ms, true)
              increase_latency_bucket(operation, index)
            else
              concatenate_latency(operation, time_in_ms)
            end
          end

          def add_gauge(gauge, value)
            gauge_hash = @gauges.find { |g| g[:name] == gauge }
            if gauge_hash.nil?
              gauge_value = ValueAndCount.new
              gauge_value.set_value(value)
              @gauges << { name: gauge, value: gauge_value }
            else
              gauge_hash[:value].set_value(value)
            end
          end

          def counts
            @counts.each_with_object({}) do |count, memo|
              memo[count[:name]] = count[:delta].sum
            end
          end

          def latencies
            @latencies.each_with_object({}) do |latency, memo|
              memo[latency[:operation]] = latency[:latencies]
            end
          end

          def gauges
            # TODO
          end

          def fix_latencies
            # NOOP
          end

          def clear_counts
            @counts = []
          end

          def clear_latencies
            @latencies = []
          end

          def clear_gauges
            @gauges = []
          end

          def clear
            clear_counts
            clear_latencies
            clear_gauges
          end

          #
          # small class to act as DTO for counts
          #
          class SumAndCount
            attr_reader :count
            attr_reader :sum

            def initialize
              @count = 0
              @sum = 0
            end

            def add_delta(delta)
              @count += 1
              @sum += delta
            end

            def clear
              @count = 0
              @sum = 0
            end
          end

          #
          # small class to act as DTO for gauges
          #
          class ValueAndCount
            attr_reader :count
            attr_reader :value

            def initialize
              @count = 0
              @value = 0
            end

            def set_value(value)
              @count += 1
              @value = value
            end

            def clear
              @count = 0
              @value = 0
            end
          end

          private

          def increase_latency_bucket(operation, index)
            operation_latencies = find_operation_latencies(operation)

            if (operation_latencies.nil?)
              latencies_array = Array.new(BinarySearchLatencyTracker::BUCKETS.length, 0)
              latencies_array[index] = 1
              @latencies << { operation: operation, latencies: latencies_array }
            else
              operation_latencies[:latencies][index] += 1
            end
          end

          def concatenate_latency(operation, time_in_ms)
            operation_latencies = find_operation_latencies(operation)

            if (operation_latencies.nil?)
              @latencies << { operation: operation, latencies: [time_in_ms] }
            else
              operation_latencies[:latencies].push(time_in_ms)
            end
          end

          def find_operation_latencies(operation)
            @latencies.find { |l| l[:operation] == operation }
          end
        end
      end
    end
  end
end
