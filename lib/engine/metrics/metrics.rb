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

    def initialize(queue_size, config)
      @queue_size = queue_size
      @binary_search = SplitIoClient::BinarySearchLatencyTracker.new

      @config = config

      @repository = Cache::Repositories::MetricsRepository.new(@config.metrics_adapter, @config)
    end

    #
    # creates a new entry in the array for cached counts
    #
    # @param counter [string] name of the counter
    # @delta [int] value of the counter
    #
    # @return void
    def count(counter, delta)
      return if (delta <= 0) || counter.nil? || counter.strip.empty?

      @repository.add_count(counter, delta)
    end

    #
    # creates a new entry in the array for cached time metrics
    #
    # @param operation [string] name of the operation
    # @time_in_ms [number] time in miliseconds
    #
    # @return void
    def time(operation, time_in_ms)
      return if operation.nil? || operation.empty? || time_in_ms < 0

      @repository.add_latency(operation, time_in_ms, @binary_search)
    end

    #
    # creates a new entry in the array for cached gauges
    #
    # @param gauge [string] name of the gauge
    # @value [number] value of the gauge
    #
    # @return void
    def gauge(gauge, value)
      return if gauge.nil? || gauge.empty?

      @repository.add_gauge(gauge, value)
    end
  end
end
