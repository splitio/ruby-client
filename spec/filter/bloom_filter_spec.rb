# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Filter::BloomFilter do
  subject { SplitIoClient::Cache::Filter::BloomFilter }

  it 'validate add, contains and clear of Bloomfilter implementation' do
    bf = subject.new(1_000)

    expect(bf.add('feature-1::custom-key-1')).to eq(true)
    expect(bf.add('feature-1::custom-key-2')).to eq(true)
    expect(bf.add('feature-1::custom-key-3')).to eq(true)
    expect(bf.add('feature-1::custom-key-4')).to eq(true)

    expect(bf.contains?('feature-1::custom-key-1')).to eq(true)
    expect(bf.contains?('feature-1::custom-key-2')).to eq(true)
    expect(bf.contains?('feature-1::custom-key-3')).to eq(true)
    expect(bf.contains?('feature-1::custom-key-4')).to eq(true)
    expect(bf.contains?('feature-1::custom-key-5')).to eq(false)

    bf.clear

    expect(bf.contains?('feature-1::custom-key-1')).to eq(false)
    expect(bf.contains?('feature-1::custom-key-2')).to eq(false)
    expect(bf.contains?('feature-1::custom-key-3')).to eq(false)
    expect(bf.contains?('feature-1::custom-key-4')).to eq(false)
  end
end
