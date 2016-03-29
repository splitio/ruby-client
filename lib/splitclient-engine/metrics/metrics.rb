module SplitIoClient

  #
  # class to handle cached metrics
  #
  class Metrics < NoMethodError

    @counter
    @delta

    #
    # cached latencies
    #
    # @return [object] array of latencies
    attr_accessor :latencies

    #
    # cached counts
    #
    # @return [object] array of counts
    attr_accessor :counts

    #
    # cached gauges
    #
    # @return [object] array of gauges
    attr_accessor :gauges

    #
    # quese size for cached arrays
    #
    # @return [int] queue size
    attr_accessor :queue_size

    def initialize(queue_size)
      @latencies = []
      @counts = []
      @gauges = []
      @queue_size = queue_size
      @binary_search = SplitIoClient::BinarySearchLatencyTracker.new
    end

    #
    # creates a new entry in the array for cached counts
    #
    # @param counter [string] name of the counter
    # @delta [int] value of the counter
    #
    # @return void
    def count(counter, delta)
      return if delta <= 0

      return if (counter.nil? || counter.strip.empty?)

      counter_hash = @counts.find { |c| c[:name] == counter }
      if counter_hash.nil?
        counter_delta = SumAndCount.new
        counter_delta.add_delta(delta)
        @counts << {name: counter, delta: counter_delta}
      else
        counter_hash[:delta].add_delta(delta)
      end
    end

    #
    # creates a new entry in the array for cached time metrics
    #
    # @param operation [string] name of the operation
    # @time_in_ms [number] time in miliseconds
    #
    # @return void
    def time(operation, time_in_ms)

      if operation.nil? || operation.empty? || time_in_ms < 0
        return;
      end

      operation_hash = @latencies.find { |l| l[:operation] == operation }
      if operation_hash.nil?
        latencies_for_op = (operation == 'sdk.get_treatment') ? @binary_search.add_latency_millis(time_in_ms) : [time_in_ms]
        @latencies << {operation: operation, latencies: latencies_for_op}
      else
        latencies_for_op = (operation == 'sdk.get_treatment') ? @binary_search.add_latency_millis(time_in_ms) : operation_hash[:latencies].push(time_in_ms)
      end
    end

    #
    # creates a new entry in the array for cached gauges
    #
    # @param gauge [string] name of the gauge
    # @value [number] value of the gauge
    #
    # @return void
    def gauge(gauge, value)
      if gauge.nil? || gauge.empty?
        return
      end

      gauge_hash = @gauges.find { |g| g[:name] == gauge }
      if gauge_hash.nil?
        gauge_value = ValueAndCount.new
        gauge_value.set_value(value)
        @gauges << {name: gauge, value: gauge_value}
      else
        gauge_hash[:value].set_value(value)
      end
    end

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
      @count++
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

end
