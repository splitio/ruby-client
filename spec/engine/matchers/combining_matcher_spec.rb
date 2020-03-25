# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::CombiningMatcher do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', logger: Logger.new('/dev/null'), streaming_enabled: false).client
  end

  let(:splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/combining_matcher_splits.json')))
  end
  let(:segments_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/segments/combining_matcher_segments.json')))
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments_json)
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_json)
  end

  describe 'anding' do
    it 'matches' do
      expect(subject.get_treatment(
               'user_for_testing_do_no_erase',
               'PASSENGER_anding',
               'join' => 1_461_283_200,
               'custom_attribute' => 'usa'
             )).to eq('V-YZKS')
    end
  end
end
