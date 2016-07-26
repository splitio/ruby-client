require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('111',{base_uri: 'http://localhost:8081/api/', logger: Logger.new("/dev/null")}).client }

  let(:split_between_number_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"income"}, :matcherType=>"BETWEEN", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>nil, :betweenMatcherData=>{:dataType=>"NUMBER", :start=>100, :end=>120}}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}, {:treatment=>"default", :size=>0}]}]}) }

  let(:split_between_negative_number_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"income"}, :matcherType=>"BETWEEN", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>nil, :betweenMatcherData=>{:dataType=>"NUMBER", :start=>-100, :end=>120}}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}, {:treatment=>"default", :size=>0}]}]}) }

  let(:split_between_datetime_matcher) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf", :name=>"test_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-195840228, :status=>"ACTIVE", :killed=>false, :defaultTreatment=>"default", :conditions=>[{:matcherGroup=>{:combiner=>"AND", :matchers=>[{:keySelector=>{:trafficType=>"user", :attribute=>"created"}, :matcherType=>"BETWEEN", :negate=>false, :userDefinedSegmentMatcherData=>nil, :whitelistMatcherData=>nil, :unaryNumericMatcherData=>nil, :betweenMatcherData=>{:dataType=>"DATETIME", :start=>1451687340000, :end=>1459722588398}}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"off", :size=>0}, {:treatment=>"default", :size=>0}]}]}) }

  describe "between matcher behaves as expected with number" do

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}
    let(:user) { 'fake_user_id_1' }
    let(:feature) { 'test_feature' }
    let(:matching_attributes) { {income: 110} }
    let(:matching_inclusive_low_attributes) { {income: 100} }
    let(:matching_inclusive_high_attributes) { {income: 120} }
    let(:non_matching_low_value_attributes) { {income: 99} }
    let(:non_matching_high_value_attributes) { {income: 121} }

    let(:matching_inclusive_negative_low_attributes) { {income: -100} }
    let(:matching_negative_attributes) { {income: -10} }
    let(:non_matching_low_value_negative_attributes) { {income: -999} }

    let(:missing_key_attributes) { {} }
    let(:nil_attributes) { nil }

    it 'validates the treatment is ON for correct number attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_between_number_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_inclusive_low_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_inclusive_high_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect number attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_between_number_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_low_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end

    it 'validates the treatment is ON for correct negative numbers attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_between_negative_number_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_inclusive_negative_low_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect negative number attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_between_negative_number_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_low_value_negative_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end
  end

  describe "between matcher behaves as expected with datetime" do

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}
    let(:user) { 'fake_user_id_1' }
    let(:feature) { 'test_feature' }
    let(:matching_attributes) { {created: 1454414400 } } # "2016/02/02T12:00Z"
    let(:matching_inclusive_low_attributes) { {created: 1451687340 } } # "2016/01/01T22:29Z"
    let(:matching_inclusive_high_attributes) { {created: 1459722540 } } # "2016/04/03T22:29Z"
    let(:non_matching_low_value_attributes) { {created: 1420151340 } } # "2015/01/01T22:29Z"
    let(:non_matching_high_value_attributes) { {created: 1459775460 } } # "2016/04/04T13:11Z"
    let(:missing_key_attributes) { {} }
    let(:nil_attributes) { nil }

    it 'validates the treatment is ON for correct number attribute value' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_between_datetime_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, matching_inclusive_low_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_inclusive_high_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect number attributes hash and nil' do
      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_between_datetime_matcher])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user, feature, non_matching_low_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq "default"
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq "default"
    end
  end

end
