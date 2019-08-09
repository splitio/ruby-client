# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', logger: Logger.new('/dev/null')).client
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

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_json)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
      .to_return(status: 200, body: [])

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: [])
  end

  it 'validates the feature is "default" for id when segment used does not exist' do
    allow_any_instance_of(SplitIoClient::Cache::Stores::SDKBlocker).to receive(:ready?).and_return(true)
    expect(subject.get_treatment(user, feature)).to eq 'default'
  end
end
