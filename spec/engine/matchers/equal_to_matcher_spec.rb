require 'spec_helper'

describe SplitIoClient::EqualToMatcher do
  subject { SplitIoClient::SplitFactory.new('', {logger: Logger.new('/dev/null'), block_until_ready: 1}).client }

  let(:date_splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/equal_to_matcher/date_splits.json'))) }
  let(:negative_splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/equal_to_matcher/negative_splits.json'))) }
  let(:splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/equal_to_matcher/splits.json'))) }
  let(:zero_splits_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/equal_to_matcher/zero_splits.json'))) }

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }

  let(:non_matching_value_attributes) { { age: 31 } }
  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  context 'equal to number' do
    let(:matching_attributes) { { age: 30 } }

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

  context 'equal to zero' do
    let(:matching_zero_attributes) { { age: 0 } }
    let(:matching_negative_zero_attributes) { { age: -0 } }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: zero_splits_json)
    end

    it 'validates the treatment is ON for 0 and -0 attribute values' do
      expect(subject.get_treatment(user, feature, matching_zero_attributes)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_negative_zero_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for <> 0 and -0 attribute values' do
      expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq 'default'
    end
  end

  context 'equal to negative number' do
    let(:matching_negative_attributes) { { age: -1 } }
    let(:non_matching_negative_attributes) { { age: -10 } }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: negative_splits_json)
    end

    it 'validates the treatment is on for negative attribute value' do
      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for negative attribute value' do
      expect(subject.get_treatment(user, feature, non_matching_negative_attributes)).to eq 'default'
    end
  end

  context 'equal to datetime' do
    let(:matching_attributes_1) { { created: (Time.parse('2016/04/01T00:00Z')).to_i } }
    let(:matching_attributes_2) { { created: (Time.parse('2016/04/01T23:59Z')).to_i } }
    let(:non_matching_high_value_attributes) { { created: (Time.parse('2016/04/02T00:01Z')).to_i } }
    let(:non_matching_low_value_attributes) { { created: (Time.parse('2016/03/31T23:59Z')).to_i } }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: date_splits_json)
    end

    it 'validates the treatment is ON for correct number attribute value' do
      expect(subject.get_treatment(user, feature, matching_attributes_1)).to eq SplitIoClient::Treatments::ON
      expect(subject.get_treatment(user, feature, matching_attributes_2)).to eq SplitIoClient::Treatments::ON
    end

    it 'validates the treatment is the default treatment for incorrect number attributes hash and nil' do
      expect(subject.get_treatment(user, feature, non_matching_low_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end
end
