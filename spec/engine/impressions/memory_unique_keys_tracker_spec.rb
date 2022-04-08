# frozen_string_literal: true

require 'spec_helper'
require 'unique_keys_sender_adapter_test'

describe SplitIoClient::Engine::Impressions::UniqueKeysTracker do
  subject { SplitIoClient::Engine::Impressions::UniqueKeysTracker }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:bf) { SplitIoClient::Cache::Filter::BloomFilter.new(1_000) }
  let(:filter_adapter) { SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf) }

  context 'with sender_adapter' do
    let(:api_key) { 'UniqueKeysTracker-key' }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer) }
    let(:impressions_api) { SplitIoClient::Api::Impressions.new(api_key, config, runtime_producer) }
    let(:sender_adapter) { SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impressions_api) }

    it 'track - full cache and send bulk' do
      post_url = 'https://telemetry.split.io/api/v1/mtks/ss'
      body_expect = {
        mtks: [{ f: 'feature-test-0', ks: ['key_test-1', 'key_test-2'] }, { f: 'feature-test-1', ks: ['key_test-1'] }]
      }.to_json

      stub_request(:post, post_url).with(body: body_expect).to_return(status: 200, body: '')

      cache = Concurrent::Hash.new
      config.unique_keys_cache_max_size = 2
      config.unique_keys_bulk_size = 2
      tracker = subject.new(config, filter_adapter, sender_adapter, cache)

      2.times do |i|
        expect(tracker.track("feature-test-#{i}", 'key_test-1')).to eq(true)
        expect(tracker.track("feature-test-#{i}", 'key_test-2')).to eq(true)
      end

      expect(a_request(:post, post_url).with(body: body_expect)).to have_been_made

      cache.clear
    end

    it 'track - full cache and send 2 bulks' do
      post_url = 'https://telemetry.split.io/api/v1/mtks/ss'
      body_expect1 = {
        mtks: [{ f: 'feature-test-0', ks: ['key-1', 'key-2'] }, { f: 'feature-test-2', ks: ['key-1', 'key-2'] }]
      }.to_json

      body_expect2 = {
        mtks: [{ f: 'feature-test-1', ks: ['key-1', 'key-2'] }, { f: 'feature-test-3', ks: ['key-1'] }]
      }.to_json

      stub_request(:post, post_url).with(body: body_expect1).to_return(status: 200, body: '')
      stub_request(:post, post_url).with(body: body_expect2).to_return(status: 200, body: '')

      cache = Concurrent::Hash.new
      config.unique_keys_cache_max_size = 4
      config.unique_keys_bulk_size = 2
      tracker = subject.new(config, filter_adapter, sender_adapter, cache)

      4.times do |i|
        expect(tracker.track("feature-test-#{i}", 'key-1')).to eq(true)
        expect(tracker.track("feature-test-#{i}", 'key-2')).to eq(true)
      end

      expect(a_request(:post, post_url).with(body: body_expect1)).to have_been_made
      expect(a_request(:post, post_url).with(body: body_expect2)).to have_been_made

      cache.clear
    end
  end

  context 'with sender_adapter_test' do
    let(:sender_adapter_test) { MemoryUniqueKeysSenderTest.new }

    it 'track - should add elemets to cache' do
      cache = Concurrent::Hash.new
      config.unique_keys_cache_max_size = 5
      config.unique_keys_bulk_size = 5
      tracker = subject.new(config, filter_adapter, sender_adapter_test, cache)

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
      config.unique_keys_cache_max_size = 10
      config.unique_keys_bulk_size = 5
      tracker = subject.new(config, filter_adapter, sender_adapter_test, cache)

      10.times { |i| expect(tracker.track("feature-test-#{i}", 'key_test')).to eq(true) }

      result = sender_adapter_test.bulks

      expect(result.size).to eq(2)
      expect(result[0].size).to eq(5)
      expect(result[1].size).to eq(5)

      cache.clear
    end
  end
end
