# frozen_string_literal: true

require 'spec_helper'
require 'filter_imp_test'

describe SplitIoClient::Engine::Impressions::UniqueKeysTracker do
  subject { SplitIoClient::Engine::Impressions::UniqueKeysTracker }

  let(:config) do
    SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new), cache_adapter: :redis, redis_namespace: 'tracker-prefix')
  end
  let(:sender_adapter) do
    api_key = 'UniqueKeysTracker-key'
    runtime_producer = SplitIoClient::Telemetry::RuntimeProducer.new(config)
    telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer)
    impressions_api = SplitIoClient::Api::Impressions.new(api_key, config, runtime_producer)

    SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impressions_api)
  end
  let(:filter_adapter) do
    bf = FilterTest.new
    SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf)
  end

  it 'track - full cache and send bulk' do
    key = "#{config.redis_namespace}.uniquekeys"

    cache = Concurrent::Hash.new
    config.unique_keys_cache_max_size = 20
    config.unique_keys_bulk_size = 2
    tracker = subject.new(config, filter_adapter, sender_adapter, cache)

    20.times do |i|
      expect(tracker.track("feature-test-#{i}", 'key_test-1')).to eq(true)
      expect(tracker.track("feature-test-#{i}", 'key_test-2')).to eq(true)
    end

    result = config.cache_adapter.get_from_queue(key, 0)
    expect(result.size).to eq(20)

    10.times do |i|
      data = JSON.parse(result[i], symbolize_names: true)
      expect(data.size).to eq(2)
    end

    cache.clear
  end

  it 'track - task should send bulk.' do
    key = "#{config.redis_namespace}.uniquekeys"

    cache = Concurrent::Hash.new
    config.unique_keys_refresh_rate = 0.5
    tracker = subject.new(config, filter_adapter, sender_adapter, cache)

    tracker.call

    10.times do |i|
      expect(tracker.track("feature-test-#{i}", 'key_test-1')).to eq(true)
      expect(tracker.track("feature-test-#{i}", 'key_test-2')).to eq(true)
    end

    sleep 1

    result = config.cache_adapter.get_from_queue(key, 0)
    expect(result.size).to eq(10)

    10.times do |i|
      data = JSON.parse(result[i], symbolize_names: true)
      expect(data[:ks].size).to eq(2)
    end

    cache.clear
  end
end
