# frozen_string_literal: true

require 'spec_helper'
require 'bloomfilter-rb'
require 'unique_keys_sender_adapter_test'

describe SplitIoClient::Engine::Impressions::UniqueKeysTracker do
  subject { SplitIoClient::Engine::Impressions::UniqueKeysTracker }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:bf) { BloomFilter::Native.new(size: 100, hashes: 2, seed: 1, bucket: 3, raise: false) }
  let(:filter_adapter) { SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf) }
  let(:sender_adapter) { MemoryUniqueKeysSenderTest.new }

  it 'track - should add elemets to cache' do
    cache = Concurrent::Hash.new
    component_config = { cache_max_size: 5, max_bulk_size: 5 }
    tracker = subject.new(config, filter_adapter, sender_adapter, cache, component_config)

    expect(tracker.track('feature_name_test', 'key_test')).to eq(true)
    expect(tracker.track('feature_name_test', 'key_test')).to eq(false)
    expect(tracker.track('feature_name_test', 'key_test-1')).to eq(true)
    expect(tracker.track('feature_name_test', 'key_test-2')).to eq(true)
    expect(tracker.track('other_test', 'key_test-2')).to eq(true)
    expect(tracker.track('other_test', 'key_test-35')).to eq(true)

    expect(cache.size).to eq(2)
    expect(cache['feature_name_test'].include?('key_test')).to eq(true)
    expect(cache['feature_name_test'].include?('key_test-1')).to eq(true)
    expect(cache['feature_name_test'].include?('key_test-2')).to eq(true)
    expect(cache['feature_name_test'].include?('key_test-35')).to eq(false)

    expect(cache['other_test'].include?('key_test-2')).to eq(true)
    expect(cache['other_test'].include?('key_test-35')).to eq(true)
    expect(cache['other_test'].include?('key_test-1')).to eq(false)

    cache.clear
  end

  it 'track - full cache and send bulk' do
    cache = Concurrent::Hash.new
    component_config = { cache_max_size: 10, max_bulk_size: 5 }
    tracker = subject.new(config, filter_adapter, sender_adapter, cache, component_config)

    10.times { |i| expect(tracker.track("feature-test-#{i}", 'key_test')).to eq(true) }

    result = sender_adapter.bulks

    expect(result.size).to eq(2)
    expect(result[0].size).to eq(5)
    expect(result[1].size).to eq(5)

    cache.clear
  end
end
