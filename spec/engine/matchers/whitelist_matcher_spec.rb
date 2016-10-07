require 'spec_helper'

describe SplitIoClient::WhitelistMatcher do
  subject { SplitIoClient::SplitFactory.new('', { logger: Logger.new('/dev/null') }).client }

  let(:splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/whitelist_matcher_splits.json'))) }

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }
  let(:matching_attributes) { { list: 'pro' } }
  let(:non_matching_value_attributes) { { list: 'random' } }
  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_json)
  end

  it 'validates the treatment is ON for correct attribute value' do
    expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Treatments::ON
  end

  it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
    expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq 'default'
    expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
    expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
  end
end
