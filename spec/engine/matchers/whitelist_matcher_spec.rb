# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::WhitelistMatcher do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', {logger: Logger.new('/dev/null'), streaming_enabled: false, impressions_refresh_rate: 9999, impressions_mode: :none, features_refresh_rate: 9999, telemetry_refresh_rate: 99999}).client
  end

  let(:splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/whitelist_matcher_splits.json')))
  end

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }
  let(:matching_attributes) { { list: 'pro' } }
  let(:non_matching_value_attributes) { { list: 'random' } }
  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  before do
    stub_request(:any, /https:\/\/telemetry.*/)
      .to_return(status: 200, body: 'ok')
    stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?s=1\.1&since/)
      .to_return(status: 200, body: splits_json)
    stub_request(:any, /https:\/\/events.*/)
      .to_return(status: 200, body: "", headers: {})
  end

  it 'validates the treatment is ON for correct attribute value' do
    subject.block_until_ready
    expect(subject.get_treatment(user, feature, matching_attributes)).to eq 'on'
  end

  it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
    subject.block_until_ready
    expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq 'default'
    expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
    expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    sleep 1
    subject.destroy()
  end
end
