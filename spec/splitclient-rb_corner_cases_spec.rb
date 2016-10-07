require 'spec_helper'
require 'securerandom'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('111',{base_uri: 'http://localhost:8081/api/', logger: Logger.new("/dev/null")}).client }

  let(:segment_1) { SplitIoClient::Segment.new({:name=>"test_segment", :added=>["fake_user_id_3"],
    :removed=>[], :since=>-1, :till=>1452026405473}) }

  let(:split_missing_segment) { SplitIoClient::Split.new({:orgId=>"cee838c0-b3eb-11e5-855f-4eacec19f7bf", :environment=>"cf2d09f0-b3eb-11e5-855f-4eacec19f7bf",
     :name=>"new_feature", :trafficTypeId=>"u", :trafficTypeName=>"User", :seed=>-1177551240, :status=>"ACTIVE",
      :killed=>false, :defaultTreatment=>"def_test", :conditions=>[{:matcherGroup=>{:combiner=>"AND",
         :matchers=>[{:matcherType=>"IN_SEGMENT", :negate=>false, :userDefinedSegmentMatcherData=>{:segmentName=>"segmentWhichDoesNotExist"},
            :whitelistMatcherData=>nil}]}, :partitions=>[{:treatment=>"on", :size=>100}, {:treatment=>"control", :size=>0}]}]}) }


  describe "#get_treatment returns CONTROL on feature when id is IN_SEGMENT when segment used does not exist" do
    let(:user_1) { 'fake_user_id_1' }
    let(:feature) { 'new_feature' }

    let(:api_adapter) { subject.instance_variable_get(:@adapter)}

    it 'validates the feature is CONTROL for id' do
      parsed_segments = api_adapter.instance_variable_get(:@parsed_segments)
      till = segment_1.till
      since = segment_1.since

      parsed_segments.instance_variable_set(:@segments, [segment_1])
      api_adapter.instance_variable_set(:@parsed_segments, parsed_segments)

      parsed_splits = api_adapter.instance_variable_get(:@parsed_splits)
      parsed_splits.instance_variable_set(:@splits, [split_missing_segment])
      api_adapter.instance_variable_set(:@parsed_splits, parsed_splits)

      expect(subject.get_treatment(user_1, feature)).to eq SplitIoClient::Treatments::CONTROL
    end

  end

 

end
