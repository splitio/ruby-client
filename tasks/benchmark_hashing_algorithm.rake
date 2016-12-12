require 'benchmark'
require 'digest/murmurhash'

desc 'Benchmark murmur32 hashing algorithm'

task :benchmark_hashing_algorithm do
  iterations = 200_000
  key = SecureRandom.uuid

  Benchmark.bmbm do |x|
    x.report('MurmurHash1') do
      iterations.times { Digest::MurmurHash1.rawdigest(key) }
    end

    x.report('MurmurHash2') do
      iterations.times { Digest::MurmurHash2.rawdigest(key) }
    end

    x.report('MurmurHash2A') do
      iterations.times { Digest::MurmurHash2A.rawdigest(key) }
    end

    x.report('LegacyHash') do
      iterations.times { legacy_hash(key, 123) }
    end
  end
end

def legacy_hash(key, seed)
  h = 0
  for i in 0..key.length-1
    h = to_int32(31 * h + key[i].ord)
  end
  h^seed
end

def to_int32(number)
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
