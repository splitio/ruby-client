# frozen_string_literal: true

module SplitIoClient
  #
  #  Tracks latencies pero bucket of time.
  #  Each bucket represent a latency greater than the one before
  #  and each number within each bucket is a number of calls in the range.
  #
  #  (1)  1.00
  #  (2)  1.50
  #  (3)  2.25
  #  (4)  3.38
  #  (5)  5.06
  #  (6)  7.59
  #  (7)  11.39
  #  (8)  17.09
  #  (9)  25.63
  #  (10) 38.44
  #  (11) 57.67
  #  (12) 86.50
  #  (13) 129.75
  #  (14) 194.62
  #  (15) 291.93
  #  (16) 437.89
  #  (17) 656.84
  #  (18) 985.26
  #  (19) 1,477.89
  #  (20) 2,216.84
  #  (21) 3,325.26
  #  (22) 4,987.89
  #  (23) 7,481.83
  #
  #  Created by fvitale on 2/17/16 based on java implementation by patricioe.
  #

  class BinarySearchLatencyTracker < NoMethodError
    BUCKETS = [1000,    1500, 2250, 3375, 5063,
               7594,    11_391, 17_086, 25_629, 38_443,
               57_665,   86_498,   129_746, 194_620, 291_929,
               437_894,  656_841,  985_261, 1_477_892, 2_216_838,
               3_325_257, 4_987_885, 7_481_828].freeze

    MAX_LATENCY = 7_481_828

    attr_accessor :latencies

    def initialize
      @latencies = Array.new(BUCKETS.length, 0)
    end

    #
    # Increment the internal counter for the bucket this latency falls into.
    # @param millis
    #
    def add_latency_millis(millis, return_index = false)
      index = find_bucket_index(millis * 1000)

      return index if return_index

      @latencies[index] += 1
      @latencies
    end

    # Increment the internal counter for the bucket this latency falls into.
    # @param micros
    def add_latency_micros(micros, return_index = false)
      index = find_bucket_index(micros)

      return index if return_index

      @latencies[index] += 1
      @latencies
    end

    def get_latency(index)
      @latencies[index]
    end

    def clear
      @latencies = Array.new(BUCKETS.length, 0)
    end

    #
    # Returns the counts in the bucket this latency falls into.
    # The latencies will not be updated.
    # @param latency
    # @return the bucket content for the latency.
    #
    def get_bucket_for_latency_millis(latency)
      @latencies[find_bucket_index(latency * 1000)]
    end

    #
    # Returns the counts in the bucket this latency falls into.
    # The latencies will not be updated.
    # @param latency
    # @return the bucket content for the latency.
    #
    def get_bucket_for_latency_micros(latency)
      @latencies[find_bucket_index(latency)]
    end

    private

    def find_bucket_index(micros)
      return BUCKETS.length - 1 if micros > MAX_LATENCY

      return 0 if micros < 1500

      BUCKETS.find_index(BUCKETS.bsearch { |x| x >= micros })
    end
  end
end
