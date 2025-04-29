# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::RuleBasedSegmentMatcher do
  let(:config) { SplitIoClient::SplitConfig.new(debug_enabled: true) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])}
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([])}
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
  let(:evaluator) { SplitIoClient::Engine::Parser::Evaluator.new(segments_repository, splits_repository, true) }


  context '#string_type' do
    it 'is not string type matcher' do
      expect(described_class.new(nil, nil, nil, config, nil).string_type?).to be false
    end
  end

  context 'test_matcher' do
    it 'return false if excluded key is passed' do
      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      rbs_repositoy.update([{name: 'foo', trafficTypeName: 'tt_name_1', conditions: [], excluded: {keys: ['key1'], segments: []}}], [], -1)
      matcher = described_class.new(rbs_repositoy, segments_repository, 'foo', config, nil)
      expect(matcher.match?(value: 'key1')).to be false
    end

    it 'return false if excluded segment is passed' do
      rbs_repositoy = SplitIoClient::Cache::Repositories::RuleBasedSegmentsRepository.new(config)
      segments_repository.add_to_segment({:name => 'segment1', :added => [], :removed => []})
      rbs_repositoy.update([{name: 'foo', trafficTypeName: 'tt_name_1', conditions: [], excluded: {keys: ['key1'], segments: ['segment1']}}], [], -1)
      matcher = described_class.new(rbs_repositoy, segments_repository, 'foo', config, nil)
      expect(matcher.match?(value: 'key2')).to be false
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
      matcher = described_class.new(rbs_repositoy, segments_repository, 'corge', config, evaluator)
      expect(matcher.match?({:matching_key => 'user', :attributes => {}})).to be false
      expect(matcher.match?({:matching_key => 'k1', :attributes => {}})).to be true
    end
  end
end