# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::SplitsRepository do
  RSpec.shared_examples 'SplitsRepository specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: adapter) }
    let(:repository) { described_class.new(config) }

    before :all do
      redis = Redis.new
      redis.flushall
    end

    after :all do
      redis = Redis.new
      redis.flushall
    end

    before do
      config.cache_adapter = adapter
      # in memory setup
      repository.add_split(name: 'foo', trafficTypeName: 'tt_name_1')
      repository.add_split(name: 'bar', trafficTypeName: 'tt_name_2')
      repository.add_split(name: 'baz', trafficTypeName: 'tt_name_1')

      # redis setup
      adapter.set_string(repository.send(:namespace_key, '.trafficType.tt_name_1'), '2')
      adapter.set_string(repository.send(:namespace_key, '.trafficType.tt_name_2'), '1')
    end

    it 'returns splits names' do
      expect(Set.new(repository.split_names)).to eq(Set.new(%w[foo bar baz]))
    end

    it 'returns traffic types' do
      expect(repository.traffic_type_exists('tt_name_1')).to be true
      expect(repository.traffic_type_exists('tt_name_2')).to be true
      split = { name: 'qux', trafficTypeName: 'tt_name_3' }
      repository.add_split(split)
      repository.remove_split(split)

      expect(repository.traffic_type_exists('tt_name_3')).to be false
    end

    it 'returns splits data' do
      expect(repository.splits).to eq(
        'foo' => { name: 'foo', trafficTypeName: 'tt_name_1' },
        'bar' => { name: 'bar', trafficTypeName: 'tt_name_2' },
        'baz' => { name: 'baz', trafficTypeName: 'tt_name_1' }
      )
    end
  end

  include_examples 'SplitsRepository specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new
  )
  include_examples 'SplitsRepository specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    'redis://127.0.0.1:6379/0'
  )
end
