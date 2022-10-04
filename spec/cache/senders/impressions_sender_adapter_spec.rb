# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSenderAdapter do
  subject { SplitIoClient::Cache::Senders::ImpressionsSenderAdapter }

  context 'redis' do
    let(:config) do
      SplitIoClient::SplitConfig.new(cache_adapter: :redis, redis_namespace: 'prefix-counter-test')
    end
    let(:impressions_count_key) { "#{config.redis_namespace}.impressions.count" }
    let(:unique_keys_key) { "#{config.redis_namespace}.uniquekeys" }
    let(:sender) { subject.new(config, nil, nil) }

    it 'record_uniques_key' do
      uniques = {}
      uniques['feature-name-1'] = Set.new(['key-1', 'key-2', 'key-3', 'key-4'])
      uniques['feature-name-2'] = Set.new(['key-1', 'key-2', 'key-3', 'key-4'])
      uniques['feature-name-3'] = Set.new(['key-1', 'key-2', 'key-3', 'key-4'])

      sender.record_uniques_key(uniques)

      result = config.cache_adapter.get_from_queue(unique_keys_key, 0)

      expect(result.size).to eq(1)
      data = JSON.parse(result[0], symbolize_names: true)

      expect(data[0][:f]).to eq('feature-name-1')
      expect(data[0][:k].to_s).to eq('["key-1", "key-2", "key-3", "key-4"]')

      expect(data[1][:f]).to eq('feature-name-2')
      expect(data[1][:k].to_s).to eq('["key-1", "key-2", "key-3", "key-4"]')

      expect(data[2][:f]).to eq('feature-name-3')
      expect(data[2][:k].to_s).to eq('["key-1", "key-2", "key-3", "key-4"]')
    end

    it 'record_uniques_key when uniques is nil or empty' do
      sender.record_uniques_key({})
      expect(config.cache_adapter.exists?(unique_keys_key)).to eq(false)

      sender.record_uniques_key(nil)
      expect(config.cache_adapter.exists?(unique_keys_key)).to eq(false)
    end

    it 'record_impressions_count' do
      counts = {}
      counts['feature1::1599055200000'] = 3
      counts['feature2::1599055200000'] = 2
      counts['feature1::1599058800000'] = 1

      sender.record_impressions_count(counts)

      counts = {}
      counts['feature10::1599055200000'] = 3
      counts['feature20::1599055200000'] = 2
      counts['feature10::1599058800000'] = 2
      sender.record_impressions_count(counts)

      counts = {}
      counts['feature101::1599055200000'] = 1
      sender.record_impressions_count(counts)

      counts = {}
      counts['feature10::1599055200000'] = 1
      counts['feature20::1599055200000'] = 1
      counts['feature10::1599058800000'] = 1
      sender.record_impressions_count(counts)

      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature1::1599055200000').to_i).to eq(3)
      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature2::1599055200000').to_i).to eq(2)
      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature1::1599058800000').to_i).to eq(1)
      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature10::1599055200000').to_i).to eq(4)
      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature20::1599055200000').to_i).to eq(3)
      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature10::1599058800000').to_i).to eq(3)
      expect(config.cache_adapter.find_in_map(impressions_count_key, 'feature101::1599055200000').to_i).to eq(1)

      config.cache_adapter.delete(impressions_count_key)
    end

    it 'record_impressions_count when count is empty or nil' do
      sender.record_impressions_count({})
      expect(config.cache_adapter.exists?(impressions_count_key)).to eq(false)

      sender.record_impressions_count(nil)
      expect(config.cache_adapter.exists?(impressions_count_key)).to eq(false)
    end
  end

  context 'memory' do
    let(:config) { SplitIoClient::SplitConfig.new }
    let(:api_key) { 'ImpressionsSenderAdapter_Memory' }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer) }
    let(:impressions_api) { SplitIoClient::Api::Impressions.new(api_key, config, runtime_producer) }
    let(:sender) { subject.new(config, telemetry_api, impressions_api) }

    it 'record_uniques_key' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/keys/ss').to_return(status: 200, body: '')
      body_expected = '{"keys":[{"f":"feature-name-1","ks":["key-1","key-2","key-3","key-4"]},{"f":"feature-name-2","ks":["key-1","key-2","key-3","key-4"]},{"f":"feature-name-3","ks":["key-1","key-2","key-3","key-4"]}]}'

      uniques = {}
      uniques['feature-name-1'] = Set.new(['key-1', 'key-2', 'key-3', 'key-4'])
      uniques['feature-name-2'] = Set.new(['key-1', 'key-2', 'key-3', 'key-4'])
      uniques['feature-name-3'] = Set.new(['key-1', 'key-2', 'key-3', 'key-4'])

      sender.record_uniques_key(uniques)

      expect(a_request(:post, 'https://telemetry.split.io/api/v1/keys/ss').with(body: body_expected)).to have_been_made.times(1)
    end

    it 'record_uniques_key when uniques is nil or empty' do
      sender.record_uniques_key({})
      expect(a_request(:post, 'https://telemetry.split.io/api/v1/keys/ss')).to have_been_made.times(0)

      sender.record_uniques_key(nil)
      expect(a_request(:post, 'https://telemetry.split.io/api/v1/keys/ss')).to have_been_made.times(0)
    end

    it 'record_impressions_count' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: '')
      body_expected = '{"pf":[{"f":"feature1","m":1599055200000,"rc":3},{"f":"feature2","m":1599055200000,"rc":2},{"f":"feature1","m":1599058800000,"rc":1}]}'

      counts = {}
      counts['feature1::1599055200000'] = 3
      counts['feature2::1599055200000'] = 2
      counts['feature1::1599058800000'] = 1

      sender.record_impressions_count(counts)
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count').with(body: body_expected)).to have_been_made.times(1)
    end

    it 'record_impressions_count when count is empty or nil' do
      sender.record_impressions_count({})
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')).to have_been_made.times(0)

      sender.record_impressions_count(nil)
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')).to have_been_made.times(0)
    end
  end
end
