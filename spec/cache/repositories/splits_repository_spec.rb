# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::SplitsRepository do
  RSpec.shared_examples 'Splits Repository' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: cache_adapter) }
    let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::RedisFlagSetsRepository.new(config)}
    let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([])}
    let(:repository) { described_class.new(config, flag_sets_repository, flag_set_filter) }

    before :all do
      redis = Redis.new
      redis.flushall
    end

    before do
      # in memory setup
      repository.update([{name: 'foo', trafficTypeName: 'tt_name_1'},
                        {name: 'bar', trafficTypeName: 'tt_name_2'},
                        {name: 'baz', trafficTypeName: 'tt_name_1'}], [], -1)

      # redis setup
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_1'), '2'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_2'), '1'
      )
    end

    after do
      repository.update([], [{name: 'foo', trafficTypeName: 'tt_name_1'},
                            {name: 'bar', trafficTypeName: 'tt_name_2'},
                            {name: 'bar', trafficTypeName: 'tt_name_2'},
                            {name: 'qux', trafficTypeName: 'tt_name_3'},
                            {name: 'quux', trafficTypeName: 'tt_name_4'},
                            {name: 'corge', trafficTypeName: 'tt_name_5'},
                            {name: 'corge', trafficTypeName: 'tt_name_6'}], -1)
    end

    it 'returns splits names' do
      expect(Set.new(repository.split_names)).to eq(Set.new(%w[foo bar baz]))
    end

    it 'returns splits count' do
      expect(repository.splits_count).to eq(3)
    end

    it 'returns traffic types' do
      expect(repository.traffic_type_exists('tt_name_1')).to be true
      expect(repository.traffic_type_exists('tt_name_2')).to be true

      split = { name: 'qux', trafficTypeName: 'tt_name_3' }

      repository.update([split], [], -1)
      repository.update([], [split], -1)

      expect(repository.traffic_type_exists('tt_name_3')).to be false
    end

    it 'does not increment traffic type count when adding same split twice' do
      split = { name: 'quux', trafficTypeName: 'tt_name_4' }

      repository.update([split, split], [], -1)
      repository.update([], [split], -1)

      expect(repository.traffic_type_exists('tt_name_4')).to be false
    end

    it 'updates traffic type count accordingly when split changes traffic type' do
      split = { name: 'corge', trafficTypeName: 'tt_name_5' }

      repository.update([split], [], -1)
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be true

      split = { name: 'corge', trafficTypeName: 'tt_name_6' }

      repository.update([split], [], -1)

      # mimicing synchronizer internals
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '0'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_6'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be false
      expect(repository.traffic_type_exists('tt_name_6')).to be true
    end

    it 'returns splits data' do
      expect(repository.splits).to eq(
        'foo' => { name: 'foo', trafficTypeName: 'tt_name_1' },
        'bar' => { name: 'bar', trafficTypeName: 'tt_name_2' },
        'baz' => { name: 'baz', trafficTypeName: 'tt_name_1' }
      )
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Splits Repository', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Splits Repository', :redis
  end
end
