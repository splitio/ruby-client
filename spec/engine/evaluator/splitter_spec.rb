require 'spec_helper'

describe SplitIoClient::Splitter do
  RSpec.shared_examples 'murmur3 sample data' do |file|
    it 'returns expected hash and bucket' do
      File.foreach(file) do |row|
        seed, key, hash, bucket = row.split(',')

        expect(described_class.count_hash(key, seed.to_i)).to eq(hash.to_i)
        expect(described_class.bucket(hash.to_i)).to eq(bucket.to_i)
      end
    end
  end

  include_examples 'murmur3 sample data', File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/hash/murmur3-sample-data-v2.csv'))
  include_examples 'murmur3 sample data', File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/hash/murmur3-sample-data-non-alpha-numeric-v2.csv'))
end
