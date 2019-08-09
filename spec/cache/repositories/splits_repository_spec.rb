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
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_1'), '2'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_2'), '1'
      )
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

    it 'does not increment traffic type count when adding same split twice' do
      split = { name: 'quux', trafficTypeName: 'tt_name_4' }

      repository.add_split(split)
      repository.add_split(split)
      repository.remove_split(split)

      expect(repository.traffic_type_exists('tt_name_4')).to be false
    end

    it 'updates traffic type count accordingly when split changes traffic type' do
      split = { name: 'corge', trafficTypeName: 'tt_name_5' }

      repository.add_split(split)
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be true

      split = { name: 'corge', trafficTypeName: 'tt_name_6' }

      repository.add_split(split)

      # mimicing synchronizer internals
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '0'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_6'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be false
      expect(repository.traffic_type_exists('tt_name_6')).to be true

      # cleanup
      repository.remove_split(split)
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
