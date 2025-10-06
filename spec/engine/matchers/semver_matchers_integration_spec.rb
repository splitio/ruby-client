# frozen_string_literal: true

require 'spec_helper'

describe 'Semver matchers integration' do
    subject do
    SplitIoClient::SplitFactory.new('test_api_key', {
      logger: Logger.new(log),
      streaming_enabled: false,
      impressions_refresh_rate: 9999,
      impressions_mode: :none,
      features_refresh_rate: 9999,
      telemetry_refresh_rate: 99999}).client
  end

  let(:log) { StringIO.new }

  let(:semver_between_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver_matchers/semver_between.json')))
  end

  let(:semver_equalto_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver_matchers/semver_equalto.json')))
  end

  let(:semver_greater_or_equalto_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver_matchers/semver_greater_or_equalto.json')))
  end

  let(:semver_less_or_equalto_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver_matchers/semver_less_or_equalto.json')))
  end

  let(:semver_inlist_matcher_splits) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__),
                                         '../../test_data/splits/semver_matchers/semver_inlist.json')))
  end

  let(:user) { 'fake_user_id_1' }

  before do
    stub_request(:any, /https:\/\/telemetry\.*/).to_return(status: 200, body: 'ok')
    stub_request(:any, /https:\/\/events\.*/).to_return(status: 200, body: "", headers: {})
    stub_request(:any, /https:\/\/metrics\.*/).to_return(status: 200, body: "", headers: {})
    stub_request(:post, "https://telemetry.split.io/api/v1/metrics/config").to_return(status: 200, body: "", headers: {})
  end

  context 'equal to matcher' do
    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?s=1\.3&since\.*/)
        .to_return(status: 200, body: semver_equalto_matcher_splits)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: semver_equalto_matcher_splits)
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.3&since=1675259356568&rbSince=-1")
        .to_return(status: 200, body: semver_equalto_matcher_splits)
      sleep 1
      subject.block_until_ready
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, 'semver_equalto', {:version => "1.22.9"})).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, 'semver_equalto')).to eq 'off'
      expect(subject.get_treatment(user, 'semver_equalto', {:version => "1.22.10"})).to eq 'off'
      sleep 0.2
      subject.destroy()
    end
  end

  context 'greater than or equal to matcher' do
    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?s=1\.3&since/)
        .to_return(status: 200, body: semver_greater_or_equalto_matcher_splits)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: semver_greater_or_equalto_matcher_splits)
      sleep 1
      subject.block_until_ready
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, 'semver_greater_or_equalto', {:version => "1.22.9"})).to eq 'on'
      expect(subject.get_treatment(user, 'semver_greater_or_equalto', {:version => "1.22.10"})).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, 'semver_greater_or_equalto')).to eq 'off'
      expect(subject.get_treatment(user, 'semver_greater_or_equalto', {:version => "1.22.8"})).to eq 'off'
      sleep 0.2
      subject.destroy()
    end
  end

  context 'less than or equal to matcher' do
    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?s=1\.3&since=-1&rbSince=-1/)
        .to_return(status: 200, body: semver_less_or_equalto_matcher_splits)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: semver_less_or_equalto_matcher_splits)
      sleep 1
      subject.block_until_ready
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, 'semver_less_or_equalto', {:version => "1.22.9"})).to eq 'on'
      expect(subject.get_treatment(user, 'semver_less_or_equalto', {:version => "1.22.8"})).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, 'semver_less_or_equalto')).to eq 'off'
      expect(subject.get_treatment(user, 'semver_less_or_equalto', {:version => "1.22.10"})).to eq 'off'
      sleep 0.2
      subject.destroy()
    end
  end

  context 'in list matcher' do
    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?s=1\.3&since=-1&rbSince=-1/)
        .to_return(status: 200, body: semver_inlist_matcher_splits)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: semver_inlist_matcher_splits)
      sleep 1
      subject.block_until_ready
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, 'semver_inlist', {:version => "1.22.9"})).to eq 'on'
      expect(subject.get_treatment(user, 'semver_inlist', {:version => "2.1.0"})).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, 'semver_inlist')).to eq 'off'
      expect(subject.get_treatment(user, 'semver_inlist', {:version => "1.22.10"})).to eq 'off'
      sleep 0.2
      subject.destroy()
    end
  end

  context 'between matcher' do
    before do
      stub_request(:get, /https:\/\/sdk\.split\.io\/api\/splitChanges\?s=1\.3&since=-1&rbSince=-1/)
        .to_return(status: 200, body: semver_between_matcher_splits)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: semver_between_matcher_splits)
      sleep 1
      subject.block_until_ready
    end

    it 'validates the treatment is ON for correct attribute value' do
      expect(subject.get_treatment(user, 'semver_between', {:version => "1.22.9"})).to eq 'on'
      expect(subject.get_treatment(user, 'semver_between', {:version => "2.0.10"})).to eq 'on'
    end

    it 'validates the treatment is the default treatment for incorrect attributes hash and nil' do
      expect(subject.get_treatment(user, 'semver_between')).to eq 'off'
      expect(subject.get_treatment(user, 'semver_between', {:version => "1.22.9-rc1"})).to eq 'off'
      expect(subject.get_treatment(user, 'semver_between', {:version => "2.1.1"})).to eq 'off'
      sleep 0.2
      subject.destroy()
    end
  end
end
