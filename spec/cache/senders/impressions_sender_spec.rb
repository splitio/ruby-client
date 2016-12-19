require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSender do
  RSpec.shared_examples 'impressions sender specs' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5) }
    let(:adapter) { cache_adapter }
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(adapter, config) }
    let(:sender) { described_class.new(repository, config, nil) }
    let(:formatted_impressions) { sender.send(:formatted_impressions, repository.clear) }

    before :each do
      Redis.new.flushall

      repository.add('foo1',
        'key_name' => 'matching_key',
        'bucketing_key' => 'foo1',
        'treatment' => 'on',
        'label' => 'custom_label1',
        'time' => 1478113516002
      )
      repository.add('foo2',
        'key_name' => 'matching_key2',
        'bucketing_key' => 'foo2',
        'treatment' => 'off',
        'label' => 'custom_label2',
        'time' => 1478113518285
      )
    end

    it 'formats impressions to be sent' do
      expect(formatted_impressions).to match_array([
        {
          testName: 'foo1',
          keyImpressions: [{ keyName: 'matching_key', treatment: 'on', time: 1478113516002, bucketingKey: 'foo1', label: 'custom_label1' }]
        },
        {
          testName: 'foo2',
          keyImpressions: [{ keyName: 'matching_key2', treatment: 'off', time: 1478113518285, bucketingKey: 'foo2', label: 'custom_label2' }]
        }
      ])
    end

    it 'formats multiple impressions for one key' do
      repository.add('foo2', 'key_name' => 'matching_key3', 'treatment' => 'off', 'time' => 1478113518900)

      expect(formatted_impressions.find { |i| i[:testName] == 'foo1' }[:keyImpressions]).to match_array(
        [
          { keyName: 'matching_key', treatment: 'on', time: 1478113516002, bucketingKey: 'foo1', label: 'custom_label1' }
        ]
      )

      expect(formatted_impressions.find { |i| i[:testName] == 'foo2' }[:keyImpressions]).to match_array(
        [
          { keyName: 'matching_key2', treatment: 'off', time: 1478113518285, bucketingKey: 'foo2', label: 'custom_label2' },
          { keyName: 'matching_key3', treatment: 'off', time: 1478113518900, bucketingKey: nil, label: nil }
        ]
      )
    end

    it 'filters out impressions with the same key/treatment' do
      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516902)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518985)

      expect(formatted_impressions.find { |i| i[:testName] == 'foo1' }[:keyImpressions].size).to eq(1)
      expect(formatted_impressions.find { |i| i[:testName] == 'foo2' }[:keyImpressions].size).to eq(1)
    end

    it 'returns the total number of impressions' do
      impressions = formatted_impressions
      expect(sender.send(:impressions_client).total_impressions(impressions)).to eq(2)
    end
  end

  include_examples 'impressions sender specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::SizedQueueAdapter.new(3))
  include_examples 'impressions sender specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url)
end
