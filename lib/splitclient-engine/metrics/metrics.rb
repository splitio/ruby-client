module SplitIoClient

  class Metrics < NoMethodError

    @counter
    @delta
    @latency_hash
    @count_hash
    @gauge_hash

    def initialize
      @latency_hash = {}
      @count_hash = {}
      @gauge_hash = {}
    end

    def count(counter, delta)
      return if delta <= 0

      return if (counter.nil? || counter.strip.empty?)

      if_present = @count_hash.find{|c| c[:counter] == counter}
      if if_present.nil?
        if_present = SumAndCount.new
        new_count_hash = {counter:counter, sum_and_count:if_present}
        @count_hash.merge!(new_count_hash)
      end

      if_present.add_delta(delta)
    end

    def time(operation, time)
      return
    end

    def gauge(gauge, value)
      return
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

    def setValue(value)
      @count++
      @value = value
    end

    def clear
      @count = 0
      @value = 0
    end

  end

end
