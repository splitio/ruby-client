# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  let(:factory) { SplitIoClient::SplitFactory.new('test_api_key', Logger.new('/dev/null')) }
  subject { factory.manager }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits.json'))) }
  let(:segments) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/segments/engine_segments.json')))
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
      .to_return(status: 200, body: segments)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments)
  end

  context '#split' do
    let(:factory) do
      SplitIoClient.configuration = nil
      SplitIoClient::SplitFactory.new('test_api_key', logger: Logger.new(log))
    end

    let(:log) { StringIO.new }

    it 'returns nil when split is nil' do
      expect(subject.split('foo')).to eq(nil)
    end

    it 'returns on nil split_name' do
      expect(subject.split(nil)).to eq(nil)
      expect(log.string)
        .to include 'split: you passed a nil split_name, split_name must be a non-empty String or a Symbol'
    end

    it 'returns on invalid split_name' do
      expect(subject.split(123)).to eq(nil)
      expect(log.string)
        .to include 'split: you passed an invalid split_name type, split_name must be a non-empty String or a Symbol'
    end

    it 'returns on invalid split_name' do
      split_name = '  test_1_ruby '
      expect(subject.split(split_name)).not_to be_nil
      expect(log.string)
        .to include "split: split_name #{split_name} has extra whitespace, trimming"
    end
  end

  it 'returns split_names' do
    expect(subject.split_names).to match_array(%w[test_1_ruby sample_feature])
  end

  describe 'configurations' do
    let(:splits3) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits3.json'))) }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: splits3)
    end

    it 'returns configurations' do
      expect(subject.build_split_view(
        'test_1_ruby',
        subject.instance_variable_get(:@splits_repository).get_split('test_1_ruby')
      )[:configs]).to eq(on: '{"size":15,"test":20}')
    end

    it 'returns empty hash when no configurations' do
      expect(subject.build_split_view(
        'sample_feature',
        subject.instance_variable_get(:@splits_repository).get_split('sample_feature')
      )[:configs]).to be_empty
    end
  end

  describe 'treatments' do
    let(:splits4) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits4.json'))) }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: splits4)
    end

    it 'returns expected treatments' do
      expect(subject.build_split_view(
        'uber_feature',
        subject.instance_variable_get(:@splits_repository).get_split('uber_feature')
      )[:treatments]).to match_array(%w[on off])
    end
  end

  describe 'client destroy' do
    before do
      factory.client.destroy
    end

    it 'returns empty array for #splits' do
      expect(subject.splits).to eq([])
    end

    it 'returns empty array for #split_names' do
      expect(subject.split_names).to eq([])
    end

    it 'returns nil for #split' do
      expect(subject.split('uber_feature')).to be nil
    end
  end
end
