require 'spec_helper'
require 'csv'

describe SplitIoClient do
  describe 'tests for hash function' do
    let(:result) { true }

    xit 'validates all alphanumeric sample data matches' do
      CSV.foreach(File.join(File.dirname(__FILE__), '../test_data/sample-data.csv'), headers: true, header_converters: :symbol) do |row|
        hash_value = SplitIoClient::Splitter.legacy_hash(row[:key], row[:seed].to_i)
        bucket_value = SplitIoClient::Splitter.bucket(hash_value)
        unless (hash_value == row[:_hash].to_i && bucket_value == row[:_bucket].to_i)
          result = false
        end
      end
      expect(result).to be true
    end

    xit 'validates all non alphanumeric sample data matches' do
      CSV.foreach(File.join(File.dirname(__FILE__), '../test_data/sample-data-non-alpha-numeric.csv'), headers: true, header_converters: :symbol) do |row|
        hash_value = SplitIoClient::Splitter.legacy_hash(row[:key], row[:seed].to_i)
        bucket_value = SplitIoClient::Splitter.bucket(hash_value)
        unless (hash_value == row[:_hash].to_i && bucket_value == row[:_bucket].to_i)
          result = false
        end
      end
      expect(result).to be true
    end
  end
end
