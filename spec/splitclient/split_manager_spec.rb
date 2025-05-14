# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  let(:factory) { SplitIoClient::SplitFactory.new('test_api_key', logger: Logger.new(log), streaming_enabled: false) }
  let(:log) { StringIO.new }
  subject { factory.manager }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits.json'))) }
  let(:segments) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/segments/engine_segments.json'))) }

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
      .to_return(status: 200, body: splits)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
      .to_return(status: 200, body: segments)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments)

    stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
      .to_return(status: 200, body: 'ok')

    stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
      .to_return(status: 200, body: 'ok')

    stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.3&since=1473413807667&rbSince=-1")
      .to_return(status: 200, body: "", headers: {})
  end

  context '#split' do
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
      subject.block_until_ready
      split_name = '  test_1_ruby '
      expect(subject.split(split_name)).not_to be_nil
      expect(log.string).to include "split: feature_flag_name #{split_name} has extra whitespace, trimming"
    end

    it 'returns and logs warning when ready and split does not exist' do
      subject.block_until_ready
      expect(subject.split('non_existing_feature')).to be_nil
      expect(log.string).to include 'split: you passed non_existing_feature ' \
        'that does not exist in this environment, please double check what feature flags exist ' \
        'in the Split user interface'
    end

    it 'returns and logs error when not ready' do
      allow(subject).to receive(:ready?).and_return(false)

      expect(subject.split('test_feature')).to be_nil
      expect(log.string).to include 'split: the SDK is not ready, the operation cannot be executed'
    end
  end

  context '#split_names' do
    it 'returns split names' do
      subject.block_until_ready
      expect(subject.split_names).to match_array(%w[test_1_ruby sample_feature])
    end

    it 'returns empty array and logs error when not ready' do
      allow(subject).to receive(:ready?).and_return(false)

      expect(subject.split_names).to be_empty
      expect(log.string).to include 'split_names: the SDK is not ready, the operation cannot be executed'
    end
  end

  context '#splits' do
    it 'returns empty array and logs error  when not ready' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.3&since=-1")
        .to_return(status: 200, body: "", headers: {})

      allow(subject).to receive(:ready?).and_return(false)

      expect(subject.splits).to be_empty
      expect(log.string).to include 'splits: the SDK is not ready, the operation cannot be executed'
    end
  end

  context 'sets' do
    it 'return split sets in splitview' do
      subject.block_until_ready
      splits = subject.splits
      expect(splits[0][:sets]).to eq(["set_1"])
      expect(splits[1][:sets]).to eq(["set_1", "set_2"])
      expect(subject.split('test_1_ruby')[:sets]).to eq(['set_1'])
    end
  end

  describe 'configurations' do
    let(:splits3) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits3.json'))) }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: splits3)

      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.3&since=1473863097220&rbSince=-1")
        .to_return(status: 200, body: "", headers: {})
    end

    it 'returns configurations and sets' do
      subject.block_until_ready
      split = subject.instance_variable_get(:@splits_repository).get_split('test_1_ruby')
      result = subject.send(:build_split_view, 'test_1_ruby', split)
      expect(result[:configs]).to eq(on: '{"size":15,"test":20}')
      expect(result[:sets]).to eq([])
    end

    it 'returns empty hash when no configurations' do
      subject.block_until_ready
      expect(subject.send(:build_split_view,
                          'sample_feature',
                          subject.instance_variable_get(:@splits_repository).get_split('sample_feature'))[:configs])
        .to be_empty
    end
  end

  describe 'treatments' do
    let(:splits4) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits4.json'))) }

    before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: splits4)

      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.3&since")
        .to_return(status: 200, body: "", headers: {})
    end

    it 'returns expected treatments' do
      subject.block_until_ready
      expect(subject.send(:build_split_view,
                          'uber_feature',
                          subject.instance_variable_get(:@splits_repository).get_split('uber_feature'))[:treatments])
        .to match_array(%w[on off])
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
