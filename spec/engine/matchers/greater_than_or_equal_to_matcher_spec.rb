require 'spec_helper'

describe SplitIoClient::GreaterThanOrEqualToMatcher do
  subject { SplitIoClient::SplitFactory.new('', { logger: Logger.new('/dev/null') }).client }

  let(:date_splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/greater_than_or_equal_to_matcher/date_splits.json'))) }
  let(:negative_splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/greater_than_or_equal_to_matcher/negative_splits.json'))) }
  let(:splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/greater_than_or_equal_to_matcher/splits.json'))) }

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }
  let(:matching_attributes) { {age: 31} }

  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  context 'greater than or equal to number' do
    let(:non_matching_value_attributes) { {age: 29} }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: splits_json)
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq SplitIoClient::Engine::Models::Treatment::ON
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end

  context 'greater than or equal to negative number' do
    let(:matching_negative_attributes) { { age: -1 } }
    let(:non_matching_negative_attributes) { { age: -91 } }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: negative_splits_json)
    end

    it 'validates the treatment is ON for correct negative attribute value' do
      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq SplitIoClient::Engine::Models::Treatment::ON
    end

    it 'validates the treatment is the default treatment for incorrect negative attribute value' do
      expect(subject.get_treatment(user, feature, non_matching_negative_attributes)).to eq 'default'
    end

    it 'validates wrong formatted attribute does not match and returns default treatment' do
      expect(subject.get_treatment(user, feature, {age: 'asdasd'})).to eq 'default'
    end
  end

  context 'greater than or equal to date' do
    let(:matching_attributes_1) { {created: (Time.parse('2016/04/01T23:59Z')).to_i } }
    let(:matching_attributes_2) { {created: (Time.parse('2016/04/01T00:00Z')).to_i } }
    let(:non_matching_attributes_1) { {created: (Time.parse('2016/03/31T23:59Z')).to_i } }
    let(:non_matching_attributes_2) { {created: (Time.parse('2015/04/01T00:01Z')).to_i } }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: date_splits_json)
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, feature, matching_attributes_1)).to eq SplitIoClient::Engine::Models::Treatment::ON
      expect(subject.get_treatment(user, feature, matching_attributes_2)).to eq SplitIoClient::Engine::Models::Treatment::ON
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, feature, non_matching_attributes_1)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_attributes_2)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end
end
