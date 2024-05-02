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
      repository.update([{name: 'foo', trafficTypeName: 'tt_name_1', conditions: []},
                        {name: 'bar', trafficTypeName: 'tt_name_2', conditions: []},
                        {name: 'baz', trafficTypeName: 'tt_name_1', conditions: []}], [], -1)

      # redis setup
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_1'), '2'
      )
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_2'), '1'
      )
    end

    after do
      repository.update([], [{name: 'foo', trafficTypeName: 'tt_name_1', conditions: []},
                            {name: 'bar', trafficTypeName: 'tt_name_2', conditions: []},
                            {name: 'bar', trafficTypeName: 'tt_name_2', conditions: []},
                            {name: 'qux', trafficTypeName: 'tt_name_3', conditions: []},
                            {name: 'quux', trafficTypeName: 'tt_name_4', conditions: []},
                            {name: 'corge', trafficTypeName: 'tt_name_5', conditions: []},
                            {name: 'corge', trafficTypeName: 'tt_name_6', conditions: []}], -1)
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

      split = { name: 'qux', trafficTypeName: 'tt_name_3', conditions: [] }

      repository.update([split], [], -1)
      repository.update([], [split], -1)

      expect(repository.traffic_type_exists('tt_name_3')).to be false
    end

    it 'does not increment traffic type count when adding same split twice' do
      split = { name: 'quux', trafficTypeName: 'tt_name_4', conditions: [] }

      repository.update([split, split], [], -1)
      repository.update([], [split], -1)

      expect(repository.traffic_type_exists('tt_name_4')).to be false
    end

    it 'updates traffic type count accordingly when split changes traffic type' do
      split = { name: 'corge', trafficTypeName: 'tt_name_5', conditions: [] }

      repository.update([split], [], -1)
      repository.instance_variable_get(:@adapter).set_string(
        repository.send(:namespace_key, '.trafficType.tt_name_5'), '1'
      )

      expect(repository.traffic_type_exists('tt_name_5')).to be true

      split = { name: 'corge', trafficTypeName: 'tt_name_6', conditions: [] }

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
        'foo' => { name: 'foo', trafficTypeName: 'tt_name_1', conditions: [] },
        'bar' => { name: 'bar', trafficTypeName: 'tt_name_2', conditions: [] },
        'baz' => { name: 'baz', trafficTypeName: 'tt_name_1', conditions: [] }
      )
    end

    it 'remove undefined matcher with template condition' do
      split = { name: 'corge', trafficTypeName: 'tt_name_5', conditions: [
        {
            partitions: [
                {treatment: 'on', size: 50},
                {treatment: 'off', size: 50}
            ],
            contitionType: 'WHITELIST',
            label: 'some_label',
            matcherGroup: {
                matchers: [
                    {
                        matcherType: 'UNDEFINED',
                        whitelistMatcherData: {
                            whitelist: ['k1', 'k2', 'k3']
                        },
                        negate: false,
                    }
                ],
                combiner: 'AND'
            }
        }]
      }

      repository.update([split], [], -1)
      expect(repository.get_split('corge')[:conditions]).to eq SplitIoClient::Cache::Repositories::SplitsRepository::DEFAULT_CONDITIONS_TEMPLATE

      # test with multiple conditions
      split2 = {
        name: 'corge2',
        trafficTypeName: 'tt_name_5',
        conditions: [
          {
              partitions: [
                  {treatment: 'on', size: 50},
                  {treatment: 'off', size: 50}
              ],
              contitionType: 'WHITELIST',
              label: 'some_label',
              matcherGroup: {
                  matchers: [
                      {
                          matcherType: 'UNDEFINED',
                          whitelistMatcherData: {
                              whitelist: ['k1', 'k2', 'k3']
                          },
                          negate: false,
                      }
                  ],
                  combiner: 'AND'
              }
          },
          {
            partitions: [
              {treatment: 'on', size: 25},
              {treatment: 'off', size: 75}
            ],
            contitionType: 'WHITELIST',
            label: 'some_other_label',
            matcherGroup: {
              matchers: [{matcherType: 'ALL_KEYS', negate: false}],
              combiner: 'AND'
            }
          }]
        }

      repository.update([split2], [], -1)
      expect(repository.get_split('corge2')[:conditions]).to eq SplitIoClient::Cache::Repositories::SplitsRepository::DEFAULT_CONDITIONS_TEMPLATE
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Splits Repository', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Splits Repository', :redis
  end
end
