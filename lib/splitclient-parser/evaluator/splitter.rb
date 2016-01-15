require 'murmurhash3'

module SplitIoClient

  class Splitter < NoMethodError

    def self.hundred_percent_one_treatment?(partitions)
      if partitions.size != 1
        return false
      end

      return (partitions.first())[:size] == 100
    end

    def self.get_treatment(id, seed, partitions)
      if partitions.empty?
        return Treatments::CONTROL
      end

      if hundred_percent_one_treatment?(partitions)
        return (partitions.first())[:treatment]
      end

      hashed_key = MurmurHash3::V32.str_digest(id, seed)
      number_line = 100#NumberLine.NUMBER_LINE_WITH_100_BUCKETS;

      bucket_for_this_key = -1

      for i in 0..number_line do
        if hashed_key == number_line # <= number_line[i]
          bucket_for_this_key = i + 1
          break
        end
      end

      buckets_convered_thus_far = 0
      partitions.each do |p|
        buckets_convered_thus_far += p[:size]

        if buckets_convered_thus_far >= bucket_for_this_key
          return p[:treatment]
        end
      end
    end

  end

end
