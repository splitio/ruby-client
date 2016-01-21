require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('myrandomkey') }

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

    let(:segments_p) {[{:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"], :removed=>[], :since=>-1, :till=>1452026108592}, {:name=>"test_segment", :added=>["fake_user_id_3"], :removed=>[], :since=>-1, :till=>1452026405473}]}
    let(:splits_p) {[{:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"ALL_KEYS", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]} ]}

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do
      parsed_segments = fetcher.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, segments_p)
      fetcher.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, splits_p)
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be true
      expect(subject.is_on?(user_2, feature)).to be true
    end

  end


  describe "#is_on? returns true on feature when id is IN_SEGMENT" do
    let(:user_1) { 'fake_user_id_1' }
    let(:feature) { 'new_feature' }

    let(:segments_p) {[{:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"], :removed=>[], :since=>-1, :till=>1452026108592}]}
    let(:splits_p) {[{:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"demo"}, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}]}

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do
      parsed_segments = fetcher.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, segments_p)
      fetcher.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, splits_p)
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be true
    end

  end

  describe "#is_on? returns false on feature when id is not IN_SEGMENT" do
    let(:user_1) { 'fake_user_id_3' }
    let(:feature) { 'new_feature' }

    let(:segments_p) {[{:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"], :removed=>[], :since=>-1, :till=>1452026108592}]}
    let(:splits_p) {[{:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"demo"}, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}]}

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do
      parsed_segments = fetcher.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, segments_p)
      fetcher.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, splits_p)
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be false
    end

  end

  describe "#is_on? returns true on feature when id is WHITELIST" do
      let(:user_1) { 'fake_user_id_1' }
      let(:feature) { 'test_whitelist' }

      let(:splits_p) {[{:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_whitelist", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1245274114, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>{:whitelist=>["fake_user_id_1", "fake_user_id_3"]}}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}]}

      let(:fetcher) { subject.instance_variable_get(:@fetcher)}

      it 'validates the feature is on for all ids' do

        parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
        parsed_splits.instance_variable_set(:@splits, splits_p)
        fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

        expect(subject.is_on?(user_1,feature)).to be true
      end

  end

  describe "#is_on? returns false on feature when id is NOT WHITELIST" do
    let(:user_1) { 'fake_user_id_2' }
    let(:feature) { 'test_whitelist' }

    let(:splits_p) {[{:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_whitelist", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1245274114, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>{:whitelist=>["fake_user_id_1", "fake_user_id_3"]}}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}]}

    let(:fetcher) { subject.instance_variable_get(:@fetcher)}

    it 'validates the feature is on for all ids' do

      parsed_splits = fetcher.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, splits_p)
      fetcher.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.is_on?(user_1,feature)).to be false
    end

  end

  describe "#matchers validate equals? methods" do

    let(:segments_p) {[{:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"], :removed=>[], :since=>-1, :till=>1452026108592}]}
    let(:all_keys_matcher) { SplitIoClient::AllKeysMatcher.new }
    let(:negation_matcher) { SplitIoClient::NegationMatcher.new(all_keys_matcher) }
    let(:user_defined_segment_matcher) { SplitIoClient::UserDefinedSegmentMatcher.new(segments_p.first) }
    let(:user_whitelist) {["fake_user_id_1", " fake_user_id_3"]}
    let(:whitelist_matcher) { SplitIoClient::WhitelistMatcher.new(user_whitelist) }
    let(:combinining_matcher) { SplitIoClient::CombiningMatcher.new( SplitIoClient::Combiners::AND, [whitelist_matcher, user_defined_segment_matcher]) }


    it 'validates true if object equals? ALL_KEYS matcher' do
      object = all_keys_matcher
      expect(all_keys_matcher.equals?(object)).to be true
    end

    it 'validates false if object is not instance and not equals? to ALL_KEYS matcher' do
      expect(all_keys_matcher.equals?('value')).to be false
    end

    it 'validates false if object is nil and not equals? to ALL_KEYS matcher' do
      expect(all_keys_matcher.equals?(nil)).to be false
    end

    it 'validates true if object is equals? to ALL_KEYS matcher' do
      object = SplitIoClient::AllKeysMatcher.new
      expect(all_keys_matcher.equals?(object)).to be true
    end

    it 'validates to_s method for ALL_KEYS matcher' do
      expect(all_keys_matcher.to_s == 'in segment all').to be true
    end

    it 'validates true if object equals? COMIBINING matcher' do
      object = combinining_matcher
      expect(combinining_matcher.equals?(object)).to be true
    end

    it 'validates false if object is not instance and not equals to COMBINING matcher' do
      expect(combinining_matcher.equals?('value')).to be false
    end

    it 'validates false if object is nil and not equals to COMBINING matcher' do
      expect(combinining_matcher.equals?(nil)).to be false
    end

    it 'validates false if object is and not equals to COMBINING matcher' do
      object = SplitIoClient::CombiningMatcher.new( SplitIoClient::Combiners::AND, [all_keys_matcher, user_defined_segment_matcher])
      expect(combinining_matcher.equals?(object)).to be false
    end

    it 'validates to_s method for COMBINING matcher' do
      expect(combinining_matcher.to_s.include?('in segment ')).to be true
    end

    it 'validates true if key match? COMBINING matcher' do
      expect(combinining_matcher.match?('fake_user_id_1')).to be true
    end

    it 'validates false if matchers list empty on COMBINING matcher' do
      object = SplitIoClient::CombiningMatcher.new( SplitIoClient::Combiners::AND, [])
      expect(object.match?('fake_user_id_1')).to be false
    end


    it 'validates true if object equals? NEGATION matcher' do
      object = negation_matcher
      expect(negation_matcher.equals?(object)).to be true
    end

    it 'validates false if object is not instance and not equals? to NEGATION matcher' do
      expect(negation_matcher.equals?('value')).to be false
    end

    it 'validates false if object is nil and not equals? to NEGATION matcher' do
      expect(negation_matcher.equals?(nil)).to be false
    end

    it 'validates false if object is not equals? to NEGATION matcher' do
      object = SplitIoClient::NegationMatcher.new(all_keys_matcher)
      expect(negation_matcher.equals?(object)).to be false
    end

    it 'validates to_s method for NEGATION matcher' do
      expect(negation_matcher.to_s.include?('not ')).to be true
    end

    it 'validates the NEGATION matcher does not match a key' do
      expect(negation_matcher.match?('fake_id')).to be false
    end


    it 'validates true if object equals? USER DEFINED SEGMENT matcher' do
      object = user_defined_segment_matcher
      expect(user_defined_segment_matcher.equals?(object)).to be true
    end

    it 'validates false if object is nil and not equals?  to USER DEFINED SEGMENT matcher' do
      expect(user_defined_segment_matcher.equals?(nil)).to be false
    end

    it 'validates false if object is not instance and not equals? to USER DEFINED SEGMENT matcher' do
      expect(user_defined_segment_matcher.equals?('value')).to be false
    end

    it 'validates false if object is not equals? to USER DEFINED SEGMENT matcher' do
      object = SplitIoClient::UserDefinedSegmentMatcher.new(segments_p.first)
      expect(user_defined_segment_matcher.equals?(object)).to be false
    end

    it 'validates to_s method for USER DEFINED SEGMENT matcher' do
      expect(user_defined_segment_matcher.to_s.include?('in segment')).to be true
    end

    it 'validates true if object equals? WHITELIST SEGMENT matcher' do
      object = whitelist_matcher
      expect(whitelist_matcher.equals?(object)).to be true
    end

    it 'validates false if object is nil and not equals? WHITELIST SEGMENT matcher' do
      expect(whitelist_matcher.equals?(nil)).to be false
    end


    it 'validates false if object is not instance and not equals? WHITELIST SEGMENT matcher' do
      expect(whitelist_matcher.equals?('value')).to be false
    end

    it 'validates false if object is not equals? WHITELIST SEGMENT matcher' do
      object = SplitIoClient::WhitelistMatcher.new(user_whitelist)
      expect(whitelist_matcher.equals?(object)).to be false
    end

    it 'validates to_s method for WHITELIST matcher' do
      expect(whitelist_matcher.to_s.include?('in segment')).to be true
    end



  end

end