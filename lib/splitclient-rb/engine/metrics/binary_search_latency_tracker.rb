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

    BUCKETS = [ 1000,    1500,    2250,   3375,    5063,
                7594,    11391,   17086,  25629,   38443,
                57665,   86498,   129746, 194620,  291929,
                437894,  656841,  985261, 1477892, 2216838,
                3325257, 4987885, 7481828 ].freeze

    MAX_LATENCY = 7481828

    def self.get_bucket(latency)
      return find_bucket_index(latency * 1000)
    end

    private

    def self.find_bucket_index(micros)
      if (micros > MAX_LATENCY) then
        return BUCKETS.length - 1
      end

      if (micros < 1500) then
        return 0
      end

      index = BUCKETS.find_index(BUCKETS.bsearch {|x| x >= micros })

      return index
    end

  end
end
