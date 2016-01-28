module SplitIoClient

  class Splitter < NoMethodError

    def self.hundred_percent_one_treatment?(partitions)
      if partitions.size != 1
        return false
      end

      return (partitions.first).size == 100
    end

    def self.get_treatment(id, seed, partitions)
      if partitions.empty?
        return Treatments::CONTROL
      end

      if hundred_percent_one_treatment?(partitions)
        return (partitions.first).treatment
      end

      return get_treatment_for_key(bucket(hash(id, seed)), partitions)
    end

    def self.hash(key, seed)
      h = seed
      for i in 0..key.length-1
        h = 31 * h + key[i].ord
      end
      return h
    end

    def self.get_treatment_for_key(bucket, partitions)
      buckets_covered_thus_far = 0
      partitions.each do |p|
        unless p.is_empty?
          buckets_covered_thus_far += p.size
          return p.treatment if buckets_covered_thus_far >= bucket
        end
      end

      return Treatments::CONTROL
    end

    def self.bucket(hash_value)
      (hash_value % 100).abs + 1
    end

  end

end
