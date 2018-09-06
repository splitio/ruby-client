# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitFactoryBuilder do
  let(:local_treatments) do
    File.expand_path(File.join(File.dirname(__FILE__), '../test_data/local_treatments/.split'))
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: '{ "splits": [] }', headers: {})
  end

  it 'returns LocalhostSplitFactory' do
    expect(described_class.build('localhost')).to be_a(SplitIoClient::LocalhostSplitFactory)
  end

  it 'returns SplitFactory' do
    expect(described_class.build('api_key')).to be_a(SplitIoClient::SplitFactory)
  end

  it 'returns correct treatment' do
    client = described_class.build('localhost', path: local_treatments).client

    expect(client.get_treatment('*', 'foo')).to eq('on')
    expect(client.get_treatment('*', 'bar')).to eq('off')
    expect(client.get_treatment('*', 'baz')).to eq('control')
  end
end
