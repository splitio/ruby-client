require 'spec_helper'
require 'csv'

describe SplitIoClient::Splitter do
  it 'returns expected hash and bucket' do
    CSV.foreach(
      File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/hash/murmur3-sample-data-v2.csv')),
      headers: true
    ) do |row|
      expect(described_class.count_hash(row['key'], row['seed'].to_i)).to eq(row['hash'].to_i)
      expect(described_class.bucket(row['hash'].to_i)).to eq(row['bucket'].to_i)
    end
  end

  context 'non alpha numeric' do
    it 'returns expected hash and bucket' do
      CSV.foreach(
        File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/hash/murmur3-sample-data-non-alpha-numeric-v2.csv')),
        headers: true,
        quote_char: "\x02"
      ) do |row|
        expect(described_class.count_hash(row['key'], row['seed'].to_i)).to eq(row['hash'].to_i)
        expect(described_class.bucket(row['hash'].to_i)).to eq(row['bucket'].to_i)
      end
    end
  end
end
