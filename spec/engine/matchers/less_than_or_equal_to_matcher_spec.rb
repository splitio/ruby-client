# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::LessThanOrEqualToMatcher do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', {logger: Logger.new('/dev/null'), streaming_enabled: false, impressions_refresh_rate: 9999, impressions_mode: :none, features_refresh_rate: 9999, telemetry_refresh_rate: 99999}).client
  end

  let(:date_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/less_than_or_equal_to_matcher/date_splits.json')))
  end
  let(:date_splits2_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/less_than_or_equal_to_matcher/date_splits2.json')))
  end
  let(:negative_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/less_than_or_equal_to_matcher/negative_splits.json')))
  end
  let(:splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/less_than_or_equal_to_matcher/splits.json')))
  end

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }
  let(:matching_attributes) { { age: 29 } }

  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  context 'less than or equal to number' do
    let(:non_matching_value_attributes) { { age: 31 } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: "", headers: {})
      sleep 1
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
    end
  end

  context 'less than or equal to negative number' do
    let(:matching_negative_attributes) { { age: -31 } }
    let(:non_matching_negative_attributes) { { age: -1 } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: negative_splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: "", headers: {})
      sleep 1
    end

    it 'validates the treatment is ON for correct negative attribute value' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect negative attributes hash and nil' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, non_matching_negative_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end

  context 'less than or equal to date' do
    let(:matching_attributes_1) { { created: Time.parse('2016/04/01T00:00Z').to_i } }
    let(:matching_attributes_2) { { created: Time.parse('2015/04/01T23:59Z').to_i } }
    let(:non_matching_attributes_1) { { created: Time.parse('2016/04/02T00:00Z').to_i } }
    let(:non_matching_attributes_2) { { created: Time.parse('2017/04/01T00:01Z').to_i } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: date_splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: "", headers: {})
      sleep 1
    end

    it 'validates the treatment is ON for correct attribute value' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, matching_attributes_1)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_attributes_2)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, non_matching_attributes_1)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_attributes_2)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end

  context 'wrongly formed date' do
    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: date_splits2_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: "", headers: {})
      sleep 1
    end

    it 'validates the treatment is the default for wrongly formed date attribute' do
      subject.block_until_ready
      expect(subject.get_treatment(user, 'RUBY_isOnOrBeforeDateTimeWithAttributeValueThatDoesNotMatch', join: 'fer'))
        .to eq 'V1'
      sleep 1
      subject.destroy()
    end
  end
end
