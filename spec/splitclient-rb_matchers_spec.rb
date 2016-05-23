require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('myrandomkey') }

  let(:segment_1) { SplitIoClient::Segment.new({:name=>"demo", :added=>["fake_user_id_1", "fake_user_id_2"], :removed=>[], :since=>-1, :till=>1452026108592}) }

  let(:split_all_keys_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"ALL_KEYS", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }
  let(:split_segment_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"demo"}, :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}) }
  let(:split_whitelist_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_whitelist", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1245274114, :status=>"ACTIVE", :killed=>false, :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>{:whitelist=>["fake_user_id_1", "fake_user_id_3"]}}]}, :partitions=>[{:treatment=>"on", :size=>100}]}]}) }

  describe "#matchers validate equals? methods" do

    let(:all_keys_matcher) { SplitIoClient::AllKeysMatcher.new }
    let(:negation_matcher) { SplitIoClient::NegationMatcher.new(all_keys_matcher) }
    let(:user_defined_segment_matcher) { SplitIoClient::UserDefinedSegmentMatcher.new(segment_1) }
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
      segment_1.refresh_users(["fake_user_id_1", "fake_user_id_2"],[])
      segment_matcher_aux = SplitIoClient::UserDefinedSegmentMatcher.new(segment_1)
      combinining_matcher_aux = SplitIoClient::CombiningMatcher.new( SplitIoClient::Combiners::AND, [whitelist_matcher, segment_matcher_aux])
      expect(combinining_matcher_aux.match?('fake_user_id_1')).to be true
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
      object = SplitIoClient::UserDefinedSegmentMatcher.new(segment_1)
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
