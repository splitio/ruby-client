module SplitIoClient
  # Misc class in charge of providing hash functions and
  # determination of treatment based on concept of buckets
  # based on provided key
  #
  class Splitter < NoMethodError

    #
    # Checks if the partiotion size is 100%
    #
    # @param partitions [object] array of partitions
    #
    # @return [boolean] true if partition is 100% false otherwise
    def self.hundred_percent_one_treatment?(partitions)
      if partitions.size != 1
        return false
      end
      return (partitions.first).size == 100
    end


    #
    # gets the appropriate treatment based on id, seed and partition value
    #
    # @param id [string] user key
    # @param seed [number] seed for the user key
    # @param partitions [object] array of partitions
    #
    # @return traetment [object] treatment value
    def self.get_treatment(id, seed, partitions)
      if partitions.empty?
        return Treatments::CONTROL
      end

      if hundred_percent_one_treatment?(partitions)
        return (partitions.first).treatment
      end

      return get_treatment_for_key(bucket(hash(id, seed)), partitions)
    end

    #
    # returns a hash value for the give key, sedd pair
    #
    # @param key [string] user key
    # @param seed [number] seed for the user key
    #
    # @return hash [string] hash value
    def self.hash(key, seed)
      h = 0
      for i in 0..key.length-1
        h = to_int32(31 * h + key[i].ord)
      end
      h^seed
    end

    #
    # misc method to convert ruby number to int 32 since overflow is handled different to java
    #
    # @param number [number] ruby number value
    #
    # @return [int] returns the int 32 value of the provided number
    def self.to_int32(number)
      begin
        sign = number < 0 ? -1 : 1
        abs = number.abs
        return 0 if abs == 0 || abs == Float::INFINITY
      rescue
        return 0
      end

      pos_int = sign * abs.floor
      int_32bit = pos_int % 2**32

      return int_32bit - 2**32 if int_32bit >= 2**31
      int_32bit
    end

    #
    # returns the treatment for a bucket given the partitions
    #
    # @param bucket [number] bucket value
    # @param parittions [object] array of partitions
    #
    # @return treatment [treatment] treatment value for this bucket and partitions
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

    #
    # returns bucket value for the given hash value
    #
    # @param hash_value [string] hash value
    #
    # @return bucket [number] bucket number
    def self.bucket(hash_value)
      (hash_value.abs % 100) + 1
    end

  end

end
