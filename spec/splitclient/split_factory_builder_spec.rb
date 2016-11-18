require 'spec_helper'

describe SplitIoClient::SplitFactoryBuilder do
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
end
