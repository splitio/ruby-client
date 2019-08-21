# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Splitter do
  RSpec.shared_examples 'Splitter' do |file, algorithm|
    it 'returns expected hash and bucket' do
      File.foreach(file) do |row|
        seed, key, hash, bucket = row.split(',')

        expect(described_class.new.count_hash(key, seed.to_i, algorithm)).to eq(hash.to_i)
        expect(described_class.new.bucket(hash.to_i)).to eq(bucket.to_i)
      end
    end
  end

  describe 'using mumur3 algorithm' do
    it_behaves_like(
      'Splitter',
      File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/hash/murmur3-sample-data-v2.csv')),
      false
    )
  end

  describe 'using mumur3 algorithm with non-alphanumeric sample data' do
    it_behaves_like(
      'Splitter',
      File.expand_path(File.join(File.dirname(__FILE__),
                                 '../../test_data/hash/murmur3-sample-data-non-alpha-numeric-v2.csv')),
      false
    )
  end

  describe 'using legacy algorithm' do
    it_behaves_like(
      'Splitter',
      File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/hash/sample-data.csv')),
      true
    )
  end
end
