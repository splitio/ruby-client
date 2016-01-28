module SplitIoClient

  class Metrics < NoMethodError

    @counter
    @delta
    attr_accessor :latencies
    attr_accessor :counts
    attr_accessor :gauges
    attr_accessor :queue_size

    def initialize(queue_size)
      @latencies = []
      @counts = []
      @gauges = []
      @queue_size = queue_size
    end

    def count(counter, delta)
      return if delta <= 0

      return if (counter.nil? || counter.strip.empty?)

      counter_hash = @counts.find { |c| c[:name] == counter }
      if counter_hash.nil?
        counter_delta = SumAndCount.new
        counter_delta.add_delta(delta)
        @counts << {name: counter, delta: counter_delta}
      else
        #counter_delta = counter_hash[:delta]
        #counter_delta.add_delta(delta)
        #counter_hash[:delta].replace(counter_delta)
        counter_hash[:delta].add_delta(delta)
      end
    end

    def time(operation, time_in_ms)

      if operation.nil? || operation.empty? || time_in_ms < 0
        return;
      end

      operation_hash = @latencies.find { |l| l[:operation] == operation }
      if operation_hash.nil?
        latencies_for_op = [time_in_ms]
        @latencies << {operation: operation, latencies: latencies_for_op}
      else
        latencies_for_op = operation_hash[:latencies]
        if latencies_for_op.size >= @queue_size
          latencies_for_op << time_in_ms
          operation_hash[:latencies].replace(latencies_for_op)
        else
          latencies_for_op << time_in_ms
          operation_hash[:latencies].replace(latencies_for_op)
        end
      end
    end

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
        #gauge_value = gauge_hash[:value]
        #gauge_value.set_value(value)
        #gauge_hash[:value].replace(gauge_value)
        gauge_hash[:value].set_value(value)
      end
    end

  end

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
