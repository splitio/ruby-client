require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('myrandomkey') }

  let(:segment_1) { SplitIoClient::Segment.new({:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"], :removed=>[], :since=>-1, :till=>1452026108592}) }
  let(:segment_2) { SplitIoClient::Segment.new({:name=>"test_segment", :added=>["fake_user_id_3"], :removed=>[], :since=>-1, :till=>1452026405473}) }

  let(:split_all_keys_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"ALL_KEYS", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }
  let(:split_segment_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"demo"}, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}) }
  let(:split_whitelist_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_whitelist", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1245274114, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>{:whitelist=>["fake_user_id_1", "fake_user_id_3"]}}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }

  describe '#is_on? returns false on random id and feature' do
    let(:user_id) { 'my_random_user_id' }
    let(:feature) { 'my_random_feaure' }
    let(:output) { subject.is_on?(user_id,feature)}

    it 'validates the feature is off for id' do
      expect(output).to be false
    end
  end

  describe "#is_on? returns false on null id" do
    let(:feature) { 'my_random_feaure' }
    let(:output) { subject.is_on?(nil,feature)}

    it 'validates the feature is off for id' do
      expect(output).to be false
    end

  end


  describe "#is_on? returns false on null feature" do
    let(:user_id) { 'my_random_user_id' }
    let(:output) { subject.is_on?(user_id,nil)}

    it 'validates the feature is off for id' do
      expect(output).to be false
    end

  end


  describe "#is_on? returns true on feature when using ALL_KEYS matcher" do
    let(:user_1) { 'fake_user_id_1' }
    let(:user_2) { 'fake_user_id_2' }
    let(:feature) { 'test_feature' }

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do
      parsed_segments = fetcher.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      fetcher.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_all_keys_matcher])
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be true
      expect(subject.is_on?(user_2, feature)).to be true
    end

  end


  describe "#is_on? returns true on feature when id is IN_SEGMENT" do
    let(:user_1) { 'fake_user_id_1' }
    let(:feature) { 'new_feature' }

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do
      parsed_segments = fetcher.instance_variable_get(:@parsed_segments)
      till = segment_1.till
      since = segment_1.since
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      fetcher.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_segment_matcher])
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be true
    end

  end


  describe "#is_on? returns false on feature when id is not IN_SEGMENT" do
    let(:user_1) { 'fake_user_id_3' }
    let(:feature) { 'new_feature' }

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do
      parsed_segments = fetcher.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      fetcher.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_segment_matcher])
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be false
    end

  end


  describe "#is_on? returns true on feature when id is WHITELIST" do
      let(:user_1) { 'fake_user_id_1' }
      let(:feature) { 'test_whitelist' }

      let(:fetcher) { subject.instance_variable_get(:@fetcher)}

      it 'validates the feature is on for all ids' do

        parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
        parsed_splits.instance_variable_set(:@splits, [split_whitelist_matcher])
        fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

        expect(subject.is_on?(user_1,feature)).to be true
      end

  end


  describe "#is_on? returns false on feature when id is NOT WHITELIST" do
    let(:user_1) { 'fake_user_id_2' }
    let(:feature) { 'test_whitelist' }

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_whitelist_matcher])
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be false
    end

  end

end