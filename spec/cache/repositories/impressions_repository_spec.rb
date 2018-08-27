# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'impressions specs' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 5, impressions_bulk_size: 1) }
    let(:adapter) { cache_adapter }
    let(:repository) { described_class.new(adapter, config) }
    let(:split_adapter) do
      SplitIoClient::SplitAdapter.new(nil, SplitIoClient::SplitConfig.new(mode: :nil), nil, nil, nil, nil, nil)
    end
    let(:ip) { SplitIoClient::SplitConfig.machine_ip }

    before :each do
      Redis.new.flushall
    end

    it 'adds impressions' do
      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1_478_113_516_002)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1_478_113_518_285)

      expect(repository.get_batch).to match_array(
        [
          {
            feature: :foo1,
            impressions: { 'key_name' => 'matching_key',
                           'treatment' => 'on',
                           'time' => 1_478_113_516_002 },
            ip: ip
          },
          {
            feature: :foo2,
            impressions: { 'key_name' => 'matching_key2',
                           'treatment' => 'off',
                           'time' => 1_478_113_518_285 },
            ip: ip
          }
        ]
      )

      expect(repository.get_batch).to eq([])
    end

    it 'adds impressions in bulk' do
      results = {
        'foo' => { treatment: 'yes', label: 'sample label' },
        'bar' => { treatment: 'no', label: 'sample label2' }
      }

      repository.add_bulk('foo', 'sample_bucketing_key', results, Time.now)
    end
  end

  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(3)
  )
  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.new.redis_url
  )

  context 'queue size less than the actual queue' do
    before do
      Redis.new.flushall

      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1_478_113_516_002)
      repository.add('foo2', 'key_name' => 'matching_key2', 'treatment' => 'off', 'time' => 1_478_113_518_285)
      repository.add('foo2', 'key_name' => 'matching_key3', 'treatment' => 'on', 'time' => 1_478_113_518_500)
    end

    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 1) }
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url) }
    let(:repository) { described_class.new(adapter, config) }

    it 'returns impressions' do
      expect(repository.get_batch.size).to eq(2)
      expect(repository.get_batch.size).to eq(1)
    end
  end

  context 'redis exception raised on #get_batch' do
    before do
      Redis.new.flushall

      repository.add('foo1', 'key_name' => 'matching_key', 'treatment' => 'on', 'time' => 1_478_113_516_002)
    end

    let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 1) }
    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient::SplitConfig.new.redis_url) }
    let(:repository) { described_class.new(adapter, config) }

    it 'returns empty array when adapter#random_set_elements raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Adapters::RedisAdapter)
        .to receive(:random_set_elements).and_throw(RuntimeError)

      expect(repository.get_batch).to eq([])
    end

    it 'returns empty array when adapter#find_sets_by_prefix raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Adapters::RedisAdapter)
        .to receive(:find_sets_by_prefix).and_throw(RuntimeError)

      expect(repository.get_batch).to eq([])
    end
  end
end
