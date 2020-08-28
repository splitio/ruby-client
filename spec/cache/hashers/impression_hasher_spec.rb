# frozen_string_literal: true

require 'spec_helper'
require 'csv'

describe SplitIoClient::Hashers::ImpressionHasher do
  subject { SplitIoClient::Hashers::ImpressionHasher }

  it 'works' do
    impression_hasher = subject.new

    impression1 = {
      k: "some_matching_key",
      b: "some_bucketing_key",
      f: "some_feature",
      t: "some_treatment",
      r: "some_label",
      c: 123,
    }

    impression2 = {
      k: "some_matching_key",
      b: "some_bucketing_key",
      f: "some_feature",
      t: "other_treatment",
      r: "some_label",
      c: 123,
    }
    
    expect(impression_hasher.process(impression1)).not_to eq(impression_hasher.process(impression2))
  end

  it 'does not crash' do
    impression_hasher = subject.new

    impression = {
      k: "some_matching_key",
      b: "some_bucketing_key",
      f: nil,
      t: "some_treatment",
      r: "some_label",
      c: 123,
    }

    expect(impression_hasher.process(impression)).to be

    impression[:k] = nil
    expect(impression_hasher.process(impression)).to be

    impression[:c] = nil
    expect(impression_hasher.process(impression)).to be

    impression[:r] = nil
    expect(impression_hasher.process(impression)).to be

    impression[:t] = nil
    expect(impression_hasher.process(impression)).to be
  end

  it 'testing murmur3 128 with csv' do
    CSV.foreach(File.join(SplitIoClient.root, 'spec/test_data/hash/murmur3-64-128.csv')) do |row|
      key = row[0]
      seed = row[1]
      expected = row[2]

      result = Digest::MurmurHashMRI3_x64_128.rawdigest(key, [seed.to_i].pack('L'))
      
      expect(expected.to_i).to eq(result[0])
    end
  end
end