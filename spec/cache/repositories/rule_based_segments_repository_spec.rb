# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository do
  RSpec.shared_examples 'RuleBasedSegments Repository' do |cache_adapter|
    let(:config) { SplitIoClient::SplitConfig.new(cache_adapter: cache_adapter) }
    let(:repository) { described_class.new(config) }

    before :all do
      redis = Redis.new
      redis.flushall
    end

    before do
      # in memory setup
      repository.update([{name: 'foo', trafficTypeName: 'tt_name_1', conditions: []},
                        {name: 'bar', trafficTypeName: 'tt_name_2', conditions: []},
                        {name: 'baz', trafficTypeName: 'tt_name_1', conditions: []}], [], -1)
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

    it 'returns rule_based_segments names' do
      expect(Set.new(repository.rule_based_segment_names)).to eq(Set.new(%w[foo bar baz]))
    end

    it 'returns rule_based_segment data' do
      expect(repository.get_rule_based_segment('foo')).to eq(
         { conditions: [] , name: 'foo', trafficTypeName: 'tt_name_1' },
      )
    end

    it 'remove undefined matcher with template condition' do
      rule_based_segment = { name: 'corge', trafficTypeName: 'tt_name_5', conditions: [
        {
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

      repository.update([rule_based_segment], [], -1)
      expect(repository.get_rule_based_segment('corge')[:conditions]).to eq SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository::DEFAULT_CONDITIONS_TEMPLATE

      # test with multiple conditions
      rule_based_segment2 = {
        name: 'corge2',
        trafficTypeName: 'tt_name_5',
        conditions: [
          {
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
            contitionType: 'WHITELIST',
            label: 'some_other_label',
            matcherGroup: {
              matchers: [{matcherType: 'ALL_KEYS', negate: false}],
              combiner: 'AND'
            }
          }]
        }

      repository.update([rule_based_segment2], [], -1)
      expect(repository.get_rule_based_segment('corge2')[:conditions]).to eq SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository::DEFAULT_CONDITIONS_TEMPLATE
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'RuleBasedSegments Repository', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'RuleBasedSegments Repository', :redis
  end
end
