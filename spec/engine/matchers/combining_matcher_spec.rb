# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::CombiningMatcher do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', {logger: Logger.new('/dev/null'), streaming_enabled: false, impressions_refresh_rate: 9999, impressions_mode: :none, features_refresh_rate: 9999, telemetry_refresh_rate: 99999}).client
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
    stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1")
      .to_return(status: 200, body: splits_json)
    stub_request(:any, /https:\/\/telemetry.*/)
      .to_return(status: 200, body: 'ok')
    stub_request(:any, /https:\/\/events.*/)
      .to_return(status: 200, body: 'ok')
    sleep 1
  end

  describe 'anding' do
    it 'matches' do
      subject.block_until_ready

      expect(subject.get_treatment(
               'user_for_testing_do_no_erase',
               'PASSENGER_anding',
               'join' => 1_461_283_200,
               'custom_attribute' => 'usa'
             )).to eq('V-YZKS')
      sleep 1
      subject.destroy()
    end
  end
end
