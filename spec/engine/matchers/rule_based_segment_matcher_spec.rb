# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::RuleBasedSegmentMatcher do
  let(:config) { SplitIoClient::SplitConfig.new(debug_enabled: true) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])}
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([])}
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }

  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(nil, nil, nil, config).string_type?).to be false
    end
  end

  context 'test_matcher' do
    it 'return false if excluded key is passed' do
      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      rbs_repositoy.update([{name: 'foo', trafficTypeName: 'tt_name_1', conditions: [], excluded: {keys: ['key1'], segments: []}}], [], -1)
      matcher = described_class.new(segments_repository, rbs_repositoy, 'foo', config)
      expect(matcher.match?(value: 'key1')).to be false
    end

    it 'return false if excluded segment is passed' do
      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      evaluator = SplitIoClient::Engine::Parser::Evaluator.new(segments_repository, splits_repository, rbs_repositoy, true)
      segments_repository.add_to_segment({:name => 'segment1', :added => [], :removed => []})
      rbs_repositoy.update([{:name => 'foo', :trafficTypeName => 'tt_name_1', :conditions => [], :excluded => {:keys => ['key1'], :segments => [{:name => 'segment1', :type => 'standard'}]}}], [], -1)
      matcher = described_class.new(segments_repository, rbs_repositoy, 'foo', config)
      expect(matcher.match?(value: 'key2')).to be false
    end

    it 'return false if excluded rb segment is matched' do
      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      rbs = {:name => 'sample_rule_based_segment', :trafficTypeName => 'tt_name_1', :conditions => [{
              :matcherGroup => {
                :combiner => "AND",
                :matchers => [
                  {
                    :matcherType => "WHITELIST",
                    :negate => false,
                    :userDefinedSegmentMatcherData => nil,
                    :whitelistMatcherData => {
                        :whitelist => [
                          "bilal@split.io",
                          "bilal"
                        ]
                    },
                    :unaryNumericMatcherData => nil,
                    :betweenMatcherData => nil
                  }
                ]
              }
            }], :excluded => {:keys => [], :segments => [{:name => 'no_excludes', :type => 'rule-based'}]}}
      rbs2 = {:name => 'no_excludes', :trafficTypeName => 'tt_name_1', 
          :conditions => [{
              :matcherGroup => {
                :combiner => "AND",
                :matchers => [
                  {
                    :keySelector => {
                      :trafficType  => "user",
                      :attribute => "email"
                    },
                    :matcherType => "ENDS_WITH",
                    :negate => false,
                    :whitelistMatcherData => {
                      :whitelist => [
                        "@split.io"
                      ]
                    }
                  }
                ]
              }
            }
          ], :excluded => {:keys => [], :segments => []}}

      rbs_repositoy.update([rbs, rbs2], [], -1)
      matcher = described_class.new(segments_repository, rbs_repositoy, 'sample_rule_based_segment', config)
      expect(matcher.match?(value: 'bilal@split.io', attributes: {'email': 'bilal@split.io'})).to be false
      expect(matcher.match?(value: 'bilal', attributes: {'email': 'bilal'})).to be true
    end

    it 'return true if condition matches' do
      rule_based_segment = { :name => 'corge', :trafficTypeName => 'tt_name_5', 
      :excluded => {:keys => [], :segments => []},
      :conditions => [
        {
            :contitionType => 'WHITELIST',
            :label => 'some_label',
            :matcherGroup => {
                :matchers => [
                  {
                    :keySelector => nil,
                    :matcherType => 'WHITELIST',
                    :whitelistMatcherData => {
                      :whitelist => ['k1', 'k2', 'k3']
                    },
                    :negate => false,
                  }
                ],
                :combiner => 'AND'
            }
        }]
      }

      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      rbs_repositoy.update([rule_based_segment], [], -1)
      matcher = described_class.new(segments_repository, rbs_repositoy, 'corge', config)
      expect(matcher.match?({:matching_key => 'user', :attributes => {}})).to be false
      expect(matcher.match?({:matching_key => 'k1', :attributes => {}})).to be true
    end

    it 'return true if dependent rb segment matches' do
      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      rbs = {
        :changeNumber => 5,
        :name => "dependent_rbs",
        :status => "ACTIVE",
        :trafficTypeName => "user",
        :excluded =>{:keys =>["mauro@split.io","gaston@split.io"],:segments =>[]},
        :conditions => [
          {
            :matcherGroup => {
              :combiner => "AND",
              :matchers => [
                {
                  :keySelector => {
                    :trafficType => "user",
                    :attribute => "email"
                  },
                  :matcherType => "ENDS_WITH",
                  :negate => false,
                  :whitelistMatcherData => {
                    :whitelist => [
                      "@split.io"
                    ]
                  }
                }
              ]
            }
          }
        ]}
      rbs2 = {
        :changeNumber => 5,
        :name => "sample_rule_based_segment",
        :status => "ACTIVE",
        :trafficTypeName => "user",
        :excluded => {
          :keys => [],
          :segments => []
        },
        :conditions => [
          {
            :conditionType => "ROLLOUT",
            :matcherGroup => {
              :combiner => "AND",
              :matchers => [
                {
                  :keySelector => {
                    :trafficType => "user"
                  },
                  :matcherType => "IN_RULE_BASED_SEGMENT",
                  :negate => false,
                  :userDefinedSegmentMatcherData => {
                    :segmentName => "dependent_rbs"
                  }
                }
              ]
            }
          }
        ]
      }
      rbs_repositoy.update([rbs, rbs2], [], -1)
      matcher = described_class.new(segments_repository, rbs_repositoy, 'sample_rule_based_segment', config)
      expect(matcher.match?(value: 'bilal@split.io', attributes: {'email': 'bilal@split.io'})).to be true
      expect(matcher.match?(value: 'bilal', attributes: {'email': 'bilal'})).to be false
    end        
  end
end