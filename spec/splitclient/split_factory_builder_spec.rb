# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitFactoryBuilder do
  let(:log) { StringIO.new }
  let(:options) do
    {
      logger: Logger.new(log)
    }
  end
  let(:local_treatments) do
    File.expand_path(File.join(File.dirname(__FILE__), '../test_data/local_treatments/.split'))
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: '{ "splits": [] }', headers: {})
  end

  it 'returns LocalhostSplitFactory' do
    expect(described_class.build('localhost', options)).to be_a(SplitIoClient::LocalhostSplitFactory)
  end

  it 'returns SplitFactory' do
    expect(described_class.build('api_key', options)).to be_a(SplitIoClient::SplitFactory)
  end

  it 'returns correct treatment' do
    client = described_class.build('localhost', split_file: local_treatments).client

    expect(client.get_treatment('*', 'foo')).to eq('on')
    expect(client.get_treatment('*', 'bar')).to eq('off')
    expect(client.get_treatment('*', 'baz')).to eq('control')
  end

  context 'split_file set in config' do
    before do
      allow(File).to receive(:file?).with(split_file_path).and_return(true)
    end

    let(:split_file_path) { File.join(Dir.pwd, 'split.yml') }

    it 'uses provided file' do
      expect(described_class.send(:split_file, split_file_path, Logger.new(log))).to eq(split_file_path)
    end
  end

  context 'split_file not set in config' do
    before do
      allow(File).to receive(:file?).with(split_file_path).and_return(true)
    end

    let(:split_file_path) { File.join(Dir.home, '.split') }

    it 'defaults to .split and logs message' do
      expect(described_class.send(:split_file, nil, Logger.new(log))).to eq(split_file_path)
    end
  end
end
