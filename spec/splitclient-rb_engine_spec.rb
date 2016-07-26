require 'spec_helper'
require 'securerandom'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('111',{base_uri: 'http://localhost:8081/api/', logger: Logger.new("/dev/null")}).client }

  let(:segment_1) { SplitIoClient::Segment.new({:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"],
    :removed=>[], :since=>-1, :till=>1452026108592}) }
  let(:segment_2) { SplitIoClient::Segment.new({:name=>"test_segment", :added=>["fake_user_id_3"],
    :removed=>[], :since=>-1, :till=>1452026405473}) }

  let(:split_all_keys_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf",
    :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE",
    :killed=>false, :defaultTreatment=>"off", :conditions=>[{:matcherGroup=>{:combiner=>"AND",
      :matchers=>[{:matcherType=>"ALL_KEYS", :negate=>false, :userDefinedSegmentMatcherData=>nil,
        :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }

  let(:split_segment_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf",
     :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ACTIVE",
      :killed=>false, :defaultTreatment=>"def_test", :conditions=>[{:matcherGroup=>{:combiner=>"AND",
         :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"demo"},
            :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}) }

  let(:split_whitelist_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf",
     :name=>"test_whitelist", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1245274114, :status=>"ACTIVE",
      :killed=>false, :defaultTreatment=>"off", :conditions=>[{:matcherGroup=>{:combiner=>"AND",
         :matchers=>[{:matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil,
           :whitelistMatcherData=>{:whitelist=>["fake_user_id_1", "fake_user_id_3"]}}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }

  let(:split_killed) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf",
     :name=>"test_killed", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1245274114, :status=>"ACTIVE",
      :killed=>true, :defaultTreatment=>"def_test", :conditions=>[{:matcherGroup=>{:combiner=>"AND",
         :matchers=>[{:matcherType=>"ALL_KEYS", :negate=>false, :userDefinedSegmentMatcherData=>nil,
           :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }

   let(:split_segment_deleted_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf",
      :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ARCHIVED",
       :killed=>false, :defaultTreatment=>"def_test", :conditions=>[{:matcherGroup=>{:combiner=>"AND",
          :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"demo"},
             :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}) }

  describe '#get_treatment returns CONTROL on random id and feature' do
    let(:user_id) { 'my_random_user_id' }
    let(:feature) { 'my_random_feaure' }
    let(:output) { subject.get_treatment(user_id, feature) }

    it 'validates random feature returns CONTROL for random id' do
      expect(output).to be SplitIoClient::Treatments::CONTROL
    end
  end

  describe "#get_treatment returns CONTROL on null id" do
    let(:feature) { 'my_random_feaure' }
    let(:output) { subject.get_treatment(nil, feature) }

    it 'validates the treatment is CONTROL' do
      expect(output).to eq SplitIoClient::Treatments::CONTROL
    end

  end

  describe "#get_treatment returns CONTROL on null feature" do
    let(:user_id) { 'my_random_user_id' }
    let(:output) { subject.get_treatment(user_id, nil)}

    it 'validates the treatment is CONTROL' do
      expect(output).to eq SplitIoClient::Treatments::CONTROL
    end

  end

  describe "#get_treatment returns on on feature when using ALL_KEYS matcher" do
    let(:user_1) { 'fake_user_id_1' }
    let(:user_2) { 'fake_user_id_2' }
    let(:feature) { 'test_feature' }

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'validates the feature is on for all ids' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_all_keys_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_1, feature)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user_2, feature)).to eq SplitIoClient::Treatments::ON
    end

  end

  describe "#get_treatment returns true on feature when id is IN_SEGMENT" do
    let(:user_1) { 'fake_user_id_1' }
    let(:feature) { 'new_feature' }

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'validates the feature is on for all ids' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      till = segment_1.till
      since = segment_1.since
      segment_1.refresh_users(["fake_user_id_1", "fake_user_id_2"],[])
      segment_2.refresh_users(["fake_user_id_3"],[])
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_segment_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_1, feature)).to eq SplitIoClient::Treatments::ON
    end

  end

  describe "#get_treatment returns default treatment on feature when id is not IN_SEGMENT" do
    let(:user_1) { 'fake_user_id_3' }
    let(:feature) { 'new_feature' }

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'validates the feature returns default treatment for non matching ids' do
      segment_1.refresh_users(["fake_user_id_1", "fake_user_id_2"],[])
      segment_2.refresh_users(["fake_user_id_3"],[])
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_segment_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_1, feature)).to eq "def_test"
    end

  end

  describe "#get_treatment returns true on feature when id is WHITELIST" do
      let(:user_1) { 'fake_user_id_1' }
      let(:feature) { 'test_whitelist' }

      let(:api_adapter) { subject.instance_variable_get(:@adapter)}

      it 'validates the feature is on for all ids' do

        parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
        parsed_splits.instance_variable_set(:@splits, [split_whitelist_matcher])
        api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

        expect(subject.get_treatment(user_1, feature)).to eq SplitIoClient::Treatments::ON
      end

  end

  describe "#get_treatment returns false on feature when id is NOT WHITELIST" do
    let(:user_1) { 'fake_user_id_2' }
    let(:feature) { 'test_whitelist' }

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'validates the feature is on for all ids' do

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_whitelist_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_1, feature)).to eq SplitIoClient::Treatments::OFF
    end

  end

  describe "SplitFactory get_treatment responds correctly" do
    let(:user_1) { 'fake_user_id_1' }
    let(:user_2) { 'fake_user_id_2' }
    let(:user_3) { 'fake_user_id_3' }
    let(:segment_feature) { 'new_feature' }
    let(:killed_feature) { 'test_killed' }
    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'returns default treatment for killed splits' do
      allow_any_instance_of(SplitIoClient::SplitParser).to receive(:get_split).with(killed_feature).and_return(split_killed)

      expect(subject.get_treatment(user_1, killed_feature)).to eq "def_test"
      expect(subject.get_treatment(user_2, killed_feature)).to eq "def_test"
      expect(subject.get_treatment(user_3, killed_feature)).to eq "def_test"
    end

    it 'returns default treatment for active splits with a non matching id' do
      allow_any_instance_of(SplitIoClient::SplitParser).to receive(:get_split).with(segment_feature).and_return(split_segment_matcher)

      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_all_keys_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_3, segment_feature)).to eq "def_test"
    end

    it 'returns control for deleted splits' do
      allow_any_instance_of(SplitIoClient::SplitParser).to receive(:get_split).with(segment_feature).and_return(split_segment_deleted_matcher)

      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment_1, segment_2])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_all_keys_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_3, segment_feature)).to eq "control"
    end

  end

  describe "splitter key assign with 100 treatments and 100K keys" do
    it "assigns keys to each of 100 treatments following a certain distribution" do
      partitions = []
      for i in 1..100
        partitions << SplitIoClient::Partition.new({treatment: i.to_s, size: 1})
      end

      treatments = Array.new(100, 0)
      j = 100000
      k = 0.01

      for i in 0..(j-1)
        key = SecureRandom.hex(20)
        treatment = SplitIoClient::Splitter.get_treatment(key, 123, partitions)
        treatments[treatment.to_i - 1] += 1
      end

      mean = j*k
      stddev = Math.sqrt(mean * (1 - k))
      min = (mean - 4 * stddev).to_i
      max = (mean + 4 * stddev).to_i
      range = min..max

      (0..(treatments.length - 1)).each do |i|
        expect(range.cover?(treatments[i])).to be true
      end
    end
  end

end
