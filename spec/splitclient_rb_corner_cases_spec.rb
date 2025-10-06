# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', logger: Logger.new('/dev/null'), streaming_enabled: false).client
  end

  let(:splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/splits/splits.json'))) }
  let(:segments_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), 'test_data/segments/segmentNoOneUses.json')))
  end

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_1_ruby' }
  let(:non_matching_value_attributes) { { list: 'random' } }
  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }
  let(:segment_res) { '{"name":"mauro_1","added":[],"removed":[],"since":-1,"till":-1 }' }

  before do
    stub_request(:post, 'https://events.split.io/api/testImpressions/bulk').to_return(status: 200, body: '')
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1').to_return(status: 200, body: splits_json)
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1').to_return(status: 200, body: segment_res)
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1').to_return(status: 200, body: segment_res)
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=1473413807667&rbSince=-1').to_return(status: 200, body: segment_res)
    stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: segment_res)
    stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: '')
  end

  it 'validates the feature is "default" for id when segment used does not exist' do
    subject.block_until_ready
    expect(subject.get_treatment(user, feature)).to eq 'default'
  end
end
