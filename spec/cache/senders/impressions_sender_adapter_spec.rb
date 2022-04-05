# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSenderAdapter do
  subject { SplitIoClient::Cache::Senders::ImpressionsSenderAdapter }

  context 'redis' do
    let(:config) do
      SplitIoClient::SplitConfig.new(cache_adapter: :redis, redis_namespace: 'prefix-test')
    end

    it 'record_impressions_count' do
      counts = {}
      counts['feature1::1599055200000'] = 3
      counts['feature2::1599055200000'] = 2
      counts['feature1::1599058800000'] = 1

      sender = subject.new(config, nil, nil)
      sender.record_impressions_count(counts)

      counts = {}
      counts['feature10::1599055200000'] = 3
      counts['feature20::1599055200000'] = 2
      counts['feature10::1599058800000'] = 2
      sender.record_impressions_count(counts)

      key = "#{config.redis_namespace}.impressions.count"
      expect(config.cache_adapter.find_in_map(key, 'feature1::1599055200000').to_i).to eq(3)
      expect(config.cache_adapter.find_in_map(key, 'feature2::1599055200000').to_i).to eq(2)
      expect(config.cache_adapter.find_in_map(key, 'feature1::1599058800000').to_i).to eq(1)

      config.cache_adapter.delete(key)
    end
  end

  context 'memory' do
  end
end
