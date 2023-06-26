# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::EqualToMatcher do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', {logger: Logger.new('/dev/null'), streaming_enabled: false, impressions_refresh_rate: 9999, impressions_mode: :none, features_refresh_rate: 9999, telemetry_refresh_rate: 99999}).client
  end

  let(:date_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/equal_to_matcher/date_splits.json')))
  end
  let(:negative_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/equal_to_matcher/negative_splits.json')))
  end
  let(:splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/equal_to_matcher/splits.json')))
  end
  let(:zero_splits_json) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/equal_to_matcher/zero_splits.json')))
  end

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }

  let(:non_matching_value_attributes) { { age: 31 } }
  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  context 'equal to number' do
    let(:matching_attributes) { { age: 30 } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
        .to_return(status: 200, body: splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: 'ok')
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

  context 'equal to zero' do
    let(:matching_zero_attributes) { { age: 0 } }
    let(:matching_negative_zero_attributes) { { age: -0 } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
        .to_return(status: 200, body: zero_splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: 'ok')
      sleep 1
    end

    it 'validates the treatment is ON for 0 and -0 attribute values' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, matching_zero_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_negative_zero_attributes)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for <> 0 and -0 attribute values' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, non_matching_value_attributes)).to eq 'default'
    end
  end

  context 'equal to negative number' do
    let(:matching_negative_attributes) { { age: -1 } }
    let(:non_matching_negative_attributes) { { age: -10 } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
        .to_return(status: 200, body: 'ok')
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
        .to_return(status: 200, body: negative_splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: 'ok')
      sleep 1
    end

    it 'validates the treatment is on for negative attribute value' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for negative attribute value' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, non_matching_negative_attributes)).to eq 'default'
    end
  end

  context 'equal to datetime' do
    let(:matching_attributes_1) { { created: Time.parse('2016/04/01T00:00Z').to_i } }
    let(:matching_attributes_2) { { created: Time.parse('2016/04/01T23:59Z').to_i } }
    let(:non_matching_high_value_attributes) { { created: Time.parse('2016/04/02T00:01Z').to_i } }
    let(:non_matching_low_value_attributes) { { created: Time.parse('2016/03/31T23:59Z').to_i } }

    before do
      stub_request(:any, /https:\/\/telemetry.*/)
          .to_return(status: 200, body: 'ok')
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
        .to_return(status: 200, body: date_splits_json)
      stub_request(:any, /https:\/\/events.*/)
        .to_return(status: 200, body: 'ok')
      sleep 1
    end

    it 'validates the treatment is ON for correct number attribute value' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, matching_attributes_1)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_attributes_2)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect number attributes hash and nil' do
      subject.block_until_ready
      expect(subject.get_treatment(user, feature, non_matching_low_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
      sleep 1
      subject.destroy()
    end
  end
end
