require 'spec_helper'

describe SplitIoClient::Api::Splits do
  let(:splits_api) { described_class.new('', config, metrics) }
  let(:config) { SplitIoClient::SplitConfig.new }
  let(:metrics) { SplitIoClient::Metrics.new(100) }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/splits.json'))) }

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits)
  end

  it 'returns splits with segment names' do
    parsed_splits = splits_api.send(:splits_with_segment_names, splits)

    expect(parsed_splits[:segment_names]).to eq(Set.new(%w(demo employees)))
  end
end
