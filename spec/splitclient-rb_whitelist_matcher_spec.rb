require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('111',{base_uri: 'http://localhost:8081/api/', logger: Logger.new("/dev/null")}).client }

  let(:split_whitelist_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"list"}, :matcherType=>"WHITELIST", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>{:whitelist=>["pro", "premium", "standard"]}, :unaryNumericMatcherData=>nil, :betweenMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}, {:treatment=>"default", :size=>0}]}]}) }

  describe "in whitelist matcher behaves as expected" do

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}
    let(:equal_to_matcher) { SplitIoClient::EqualToMatcher.new }
    let(:user) { 'fake_user_id_1' }
    let(:feature) { 'test_feature' }
    let(:matching_attributes) { {list: "pro"} }
    let(:non_matching_value_attributes) { {list: "random"} }
    let(:missing_key_attributes) { {} }
    let(:nil_attributes) { nil }

    it 'validates the treatment is ON for correct attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_whitelist_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_whitelist_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end

  end

end
