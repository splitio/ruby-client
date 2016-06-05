require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('111',{base_uri: 'http://localhost:8081/api/', logger: Logger.new("/dev/null")}) }

  let(:segment) { SplitIoClient::Segment.new({:name=>"employees", :added=>["fake_user_id_1"], :removed=>[], :since=>-1, :till=>1452026405473}) }

  let(:split_and_matcher) { SplitIoClient::Split.new({:orgId=>nil, :environment=>nil, :trafficTypeId=>nil, :trafficTypeName=>nil, :name=>"RUBY_anding", :seed=>-2068277448, :status=>"ACTIVE", :killed=>false,
    :defaultTreatment=>"V1",
    :conditions=>[
      {:matcherGroup=>{:combiner=>"AND", :matchers=>[
        {:keySelector=>{:trafficType=>"user", :attribute=>nil},
          :matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"employees"}, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>nil, :betweenMatcherData=>nil},
        {:keySelector=>{:trafficType=>"user", :attribute=>"join"},
          :matcherType=>"BETWEEN", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>nil, :betweenMatcherData=>{:dataType=>"DATETIME", :start=>1461280821126, :end=>1462071600000}},
        {:keySelector=>{:trafficType=>"user", :attribute=>"custom_attribute"},
          :matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>{:whitelist=>["usa", "argentina"]}, :unaryNumericMatcherData=>nil, :betweenMatcherData=>nil}]},
        :partitions=>[{:treatment=>"V1", :size=>0}, {:treatment=>"V2", :size=>100}, {:treatment=>"V3", :size=>0}]},
      {:matcherGroup=>{:combiner=>"AND", :matchers=>[
        {:keySelector=>{:trafficType=>"user", :attribute=>nil},
          :matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"employees"}, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>nil, :betweenMatcherData=>nil}]},
        :partitions=>[{:treatment=>"V1", :size=>0}, {:treatment=>"V2", :size=>0}, {:treatment=>"V3", :size=>100}]}]}) }

  #if user is in segment employees
  #and
  #user.join is between 2016/04/21 11:20PM and 2016/05/01 03:00AM
  #and user.custom_attribute is in list usa, argentina
  #then split 0%:V1,100%:V2,0%:V3
  #else if user is in segment employees
  #then split 0%:V1,0%:V2,100%:V3

  describe "and matcher behaves as expected" , :focus => true do
    let(:user_included) { 'fake_user_id_1' }
    let(:user_excluded) { 'fake_user_id_2' }
    let(:attributes_included) { {custom_attribute: 'argentina', join: 1461380400} }
    let(:attributes_partially_excluded_1) { {custom_attribute: 'argentina', join: 46138040} }
    let(:attributes_partially_excluded_2) { {custom_attribute: 'chile', join: 1461380400} }
    let(:attributes_excluded) { {custom_attribute: 'chile', join: 46138040} }
    let(:feature) { 'RUBY_anding' }

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'checks that the feature is V2 for the right AND conditions' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)
      segment.refresh_users(["fake_user_id_1"],[])

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_and_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_included, feature, attributes_included)).to eq "V2"
    end

    it 'checks that the feature is V3 for the right else condition' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)
      segment.refresh_users(["fake_user_id_1"],[])

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_and_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_included, feature, attributes_excluded)).to eq "V3"
      expect(subject.get_treatment(user_included, feature, attributes_partially_excluded_1)).to eq "V3"
      expect(subject.get_treatment(user_included, feature, attributes_partially_excluded_2)).to eq "V3"
    end

    it 'checks that the feature is V1 as default treatment for a non matching set of id and attributes' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)
      segment.refresh_users(["fake_user_id_1"],[])

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_and_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_excluded, feature, attributes_excluded)).to eq "V1"
      expect(subject.get_treatment(user_excluded, feature, attributes_partially_excluded_1)).to eq "V1"
      expect(subject.get_treatment(user_excluded, feature, attributes_partially_excluded_2)).to eq "V1"
    end

    it 'checks that the feature is control for a wrong set of params' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      parsed_segments.instance_variable_set(:@segments, [segment])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)
      segment.refresh_users(["fake_user_id_1"],[])

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_and_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(nil, feature, {another: "attribute"})).to eq SplitIoClient::Treatments::CONTROL
    end
  end
end
