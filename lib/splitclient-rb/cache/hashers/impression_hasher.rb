module SplitIoClient
  module Hashers
    class ImpressionHasher
      def initialize
        @murmur_hash_128_64 = case RUBY_PLATFORM
        when 'java' 
          Proc.new { |key, seed| Java::MurmurHash3.hash128x64(key, seed) }
        else
          Proc.new { |key, seed| Digest::MurmurHashMRI3_x64_128.rawdigest(key, [seed].pack('L')) }
        end
      end

      def process(impression)
        impression_data = "#{unknown_if_null(impression[:k])}"
        impression_data << ":#{unknown_if_null(impression[:f])}"
        impression_data << ":#{unknown_if_null(impression[:t])}"
        impression_data << ":#{unknown_if_null(impression[:r])}"
        impression_data << ":#{zero_if_null(impression[:c])}"
        
        @murmur_hash_128_64.call(impression_data, 0)[0];
      end

      private

      def unknown_if_null(value)
        value == nil ? "UNKNOWN" : value
      end

      def zero_if_null(value)
        value == nil ? 0 : value
      end
    end
  end
end
