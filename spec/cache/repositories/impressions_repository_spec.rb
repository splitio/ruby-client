require 'spec_helper'
require 'set'

include SplitIoClient::Cache::Adapters

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'impressions specs' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5) }
    let(:adapter) { cache_adapter }
    let(:repository) { described_class.new(adapter, config) }
    let(:split_adapter) do
      SplitIoClient::SplitAdapter.new(nil, SplitIoClient::SplitConfig.new(mode: :nil), nil, nil, nil, nil, nil)
    end
    let(:ip) { Socket.ip_address_list.detect { |intf| intf.ipv4_private? }.ip_address }

    before :each do
      Redis.new.flushall
    end

    it 'adds impressions' do
      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516002)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518285)

      expect(repository.clear).to match_array(
        [
          { feature: 'foo1', impressions: { 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516002 }, ip: ip },
          { feature: 'foo2', impressions: { 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518285 }, ip: ip },
        ]
      )

      expect(repository.clear).to eq([])
    end

    it 'adds impressions in bulk' do
      results = {
        'foo' => { treatment: 'yes', label: 'sample label' },
        'bar' => { treatment: 'no', label: 'sample label2' }
      }

      repository.add_bulk('foo', 'sample_bucketing_key', results, Time.now)
    end
  end

  include_examples 'impressions specs', MemoryAdapter.new(MemoryAdapters::SizedQueueAdapter.new(3))
  include_examples 'impressions specs', RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url)

  context 'queue size less than the actual queue' do
    before do
      Redis.new.flushall

      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1478113516002)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1478113518285)
      repository.add('foo2', 'key_name' => 'matching_key3', 'treatment' => 'on', 'time' => 1478113518500)
    end

    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 1) }
    let(:adapter) { RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url) }
    let(:repository) { described_class.new(adapter, config) }

    it 'returns impressions' do
      expect(repository.clear.size).to eq(2)
      expect(repository.clear.size).to eq(1)
    end
  end
end
