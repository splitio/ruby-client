require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'impressions specs' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5) }
    let(:adapter) { cache_adapter }
    let(:repository) { described_class.new(adapter, config) }

    before do
      Redis.new.flushall

      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516002)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518285)
    end

    it 'adds impressions' do
      expect(Set.new(repository.clear)).to eq(
        Set.new([
          { feature: 'foo1', impressions: { 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516002 } },
          { feature: 'foo2', impressions: { 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518285 } },
        ])
      )

      expect(repository.clear).to eq([])
    end

    # TODO: Move this spec to the separate file
    it 'format impressions to be sent' do
      adapter = SplitIoClient::SplitAdapter.new(nil, SplitIoClient::SplitConfig.new(mode: :nil), nil, nil, nil, nil)
      expect(Set.new(adapter.impressions_array(repository))).to eq(Set.new([
        {
          testName: 'foo1',
          keyImpressions: [{ keyName: 'matching_key', treatment: 'on', time: 1478113516002 }]
        },
        {
          testName: 'foo2',
          keyImpressions: [{ keyName: 'matching_key2', treatment: 'off', time: 1478113518285 }]
        }
      ]))
    end
  end

  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::SizedQueueAdapter.new(3))
  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url)

  context 'queue size less than the actual queue' do
    before do
      Redis.new.flushall

      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516002)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518285)
      repository.add('foo2', 'key_name' => 'matching_key3', 'treatment' => 'on', 'time' => 1478113518500)
    end

    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 1) }
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url) }
    let(:repository) { described_class.new(adapter, config) }

    it 'returns impressions' do
      expect(repository.clear.size).to eq(2)
      expect(repository.clear.size).to eq(1)
    end
  end
end
