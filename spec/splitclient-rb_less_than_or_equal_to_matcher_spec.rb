require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitClient.new('111',{base_uri: 'http://localhost:8081/api/', logger: Logger.new("/dev/null")}) }

  let(:split_less_than_or_equal_to_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"age"}, :matcherType=>"LESS_THAN_OR_EQUAL_TO", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>{:dataType=>"NUMBER", :value=>30}, :betweenMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}]}]}) }

  let(:split_less_than_or_equal_to_negative_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"age"}, :matcherType=>"LESS_THAN_OR_EQUAL_TO", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>{:dataType=>"NUMBER", :value=>-30}, :betweenMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}]}]}) }

  let(:split_less_than_or_equal_to_date_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"created"}, :matcherType=>"LESS_THAN_OR_EQUAL_TO", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>{:dataType=>"DATETIME", :value=>1459468800000}, :betweenMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}]}]}) }

  describe "less than or equal to matcher behaves as expected with number" do

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}
    let(:user) { 'fake_user_id_1' }
    let(:feature) { 'test_feature' }
    let(:matching_attributes) { {age: 29} }
    let(:matching_negative_attributes) { {age: -31} }
    let(:non_matching_negative_attributes) { {age: -1} }
    let(:non_matching_value_attributes) { {age: 31} }
    let(:missing_key_attributes) { {} }
    let(:nil_attributes) { nil }

    it 'validates the treatment is ON for correct attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_less_than_or_equal_to_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_less_than_or_equal_to_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end

    it 'validates the treatment is ON for correct negative attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_less_than_or_equal_to_negative_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect negative attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_less_than_or_equal_to_negative_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_negative_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end

  end

  describe "less than or equal to matcher behaves as expected with datetime" do

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}
    let(:user) { 'fake_user_id_1' }
    let(:feature) { 'test_feature' }
    let(:matching_attributes_1) { {created: (Time.parse("2016/04/01T00:00Z")).to_i } }
    let(:matching_attributes_2) { {created: (Time.parse("2015/04/01T23:59Z")).to_i } }
    let(:non_matching_attributes_1) { {created: (Time.parse("2016/04/02T00:00Z")).to_i } }
    let(:non_matching_attributes_2) { {created: (Time.parse("2017/04/01T00:01Z")).to_i } }
    let(:missing_key_attributes) { {} }
    let(:nil_attributes) { nil }

    it 'validates the treatment is ON for correct attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_less_than_or_equal_to_date_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_attributes_1)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_attributes_2)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_less_than_or_equal_to_date_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_attributes_1)).to eq "default"
      expect(subject.get_treatment(user, feature, non_matching_attributes_2)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end

  end

end
