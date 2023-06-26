# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::BetweenMatcher do
  subject do
    SplitIoClient::SplitFactory.new('test_api_key', {logger: Logger.new('/dev/null'), streaming_enabled: false, impressions_refresh_rate: 9999, impressions_mode: :none, features_refresh_rate: 9999, telemetry_refresh_rate: 99999}).client
  end

  let(:datetime_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/between_matcher/datetime_matcher_splits.json')))
  end
  let(:negative_number_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/between_matcher/negative_number_matcher_splits.json')))
  end
  let(:number_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/between_matcher/number_matcher_splits.json')))
  end

  let(:user) { 'fake_user_id_1' }
  let(:feature) { 'test_feature' }
  let(:matching_attributes) { { income: 110 } }
  let(:non_matching_high_value_attributes) { { income: 121 } }
  let(:missing_key_attributes) { {} }
  let(:nil_attributes) { nil }

  before do
    stub_request(:any, /https:\/\/telemetry.*/).to_return(status: 200, body: 'ok')
    stub_request(:any, /https:\/\/events.*/).to_return(status: 200, body: "", headers: {})
  end

  context 'between positive numbers' do
    let(:matching_inclusive_low_attributes) { { income: 100 } }
    let(:matching_inclusive_high_attributes) { { income: 120 } }
    let(:non_matching_low_value_attributes) { { income: 99 } }

    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
        .to_return(status: 200, body: number_matcher_splits)
      subject.block_until_ready
      sleep 1
    end

    it 'validates the treatment is ON for correct number attribute value' do
      expect(subject.get_treatment(user, feature, matching_inclusive_low_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_inclusive_high_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect number attributes hash and nil' do
      expect(subject.get_treatment(user, feature, non_matching_low_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end

  context 'between negative numbers' do
    let(:matching_inclusive_negative_low_attributes) { { income: -100 } }
    let(:matching_negative_attributes) { { income: -10 } }
    let(:non_matching_low_value_negative_attributes) { { income: -999 } }

    before do
       stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since.*/)
        .to_return(status: 200, body: negative_number_matcher_splits)
      subject.block_until_ready
      sleep 1
    end

    it 'validates the treatment is ON for correct negative numbers attribute value' do
      expect(subject.get_treatment(user, feature, matching_inclusive_negative_low_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_negative_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect negative number attributes hash and nil' do
      expect(subject.get_treatment(user, feature, non_matching_low_value_negative_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end

  context 'between dates' do
    let(:matching_attributes) { { created: 1_454_414_400 } }
    let(:matching_inclusive_low_attributes) { { created: 1_451_687_340 } } # "2016/01/01T22:29Z"
    let(:matching_inclusive_high_attributes) { { created: 1_459_722_540 } } # "2016/04/03T22:29Z"
    let(:non_matching_low_value_attributes) { { created: 1_420_151_340 } } # "2015/01/01T22:29Z"
    let(:non_matching_high_value_attributes) { { created: 1_459_775_460 } } # "2016/04/04T13:11Z"

    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?since/)
        .to_return(status: 200, body: datetime_matcher_splits)
      subject.block_until_ready
      sleep 1
    end

    it 'validates the treatment is ON for correct number attribute value' do
      expect(subject.get_treatment(user, feature, matching_inclusive_low_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_inclusive_high_attributes)).to eq 'on'
      expect(subject.get_treatment(user, feature, matching_attributes)).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect number attributes hash and nil' do
      expect(subject.get_treatment(user, feature, non_matching_low_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, non_matching_high_value_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, missing_key_attributes)).to eq 'default'
      expect(subject.get_treatment(user, feature, nil_attributes)).to eq 'default'
    end
  end

  context '#string_type' do
    before do
      stub_request(:get, /https:\/\/sdk.*/)
        .to_return(status: 200, body: 'ok')
        sleep 1
      end

    it 'is not string type matcher' do
      expect(described_class.new({ attribute: 'foo', data_type: 'NUMBER',
                                   start_value: 0, end_value: 10 }, @split_logger, @split_validator).string_type?)
        .to be false
      sleep 1
      subject.destroy()
    end
  end
end
