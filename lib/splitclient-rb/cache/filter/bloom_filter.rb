# frozen_string_literal: true

require 'bitarray'

module SplitIoClient
  module Cache
    module Filter
      class BloomFilter
        def initialize(capacity, false_positive_probability = 0.001)
          @capacity = capacity.round
          # m is the required number of bits in the array
          m = -(capacity * Math.log(false_positive_probability)) / (Math.log(2) ** 2)
          @ba = BitArray.new(m.round)
          # k is the number of hash functions that minimizes the probability of false positives
          @k = (Math.log(2) * (@ba.size / capacity)).round
        end

        def add(string)
          return false if contains?(string)

          positions = hashes(string)
          
          positions.each { |position| @ba[position] = 1 }

          true
        end
      
        def contains?(string)
          !hashes(string).any? { |ea| @ba[ea] == 0 }
        end

        def clear
          @ba.size.times { |i| @ba[i] = 0 }
        end
      
        private

        def hashes(data)
          m = @ba.size
          h = Digest::MD5.hexdigest(data.to_s).to_i(16)
          x = h % m
          h /= m
          y = h % m
          h /= m
          z = h % m
          [x] + 1.upto(@k - 1).collect do |i|
            x = (x + y) % m
            y = (y + z) % m
            x
          end
        end
      end
    end
  end
end
