require 'digest/murmurhash'

module SplitIoClient
  # Misc class in charge of providing hash functions and
  # determination of treatment based on concept of buckets
  # based on provided key
  #
  class Splitter < NoMethodError
    class << self
      #
      # Checks if the partiotion size is 100%
      #
      # @param partitions [object] array of partitions
      #
      # @return [boolean] true if partition is 100% false otherwise
      def hundred_percent_one_treatment?(partitions)
        (partitions.size != 1) ? false : (partitions.first.size == 100)
      end

      #
      # gets the appropriate treatment based on id, seed and partition value
      #
      # @param id [string] user key
      # @param seed [number] seed for the user key
      # @param partitions [object] array of partitions
      #
      # @return traetment [object] treatment value
      def get_treatment(id, seed, partitions)
        if partitions.empty?
          return Treatments::CONTROL
        end

        if hundred_percent_one_treatment?(partitions)
          return (partitions.first).treatment
        end

        return get_treatment_for_key(bucket(count_hash(id, seed)), partitions)
      end

      # returns a hash value for the give key, seed pair
      #
      # @param key [String] user key
      # @param seed [Fixnum] seed for the user key
      #
      # @return hash [String] hash value
      def count_hash(key, seed)
        Digest::MurmurHash3_x86_32.rawdigest(key, [seed].pack('L'))
      end

      #
      # returns the treatment for a bucket given the partitions
      #
      # @param bucket [number] bucket value
      # @param parittions [object] array of partitions
      #
      # @return treatment [treatment] treatment value for this bucket and partitions
      def get_treatment_for_key(bucket, partitions)
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
      def bucket(hash_value)
        (hash_value.abs % 100) + 1
      end
    end
  end
end
