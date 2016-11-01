require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('').manager }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits.json'))) }
  let(:segments) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/segments/engine_segments.json'))) }

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits)

    stub_request(:get, "https://sdk.split.io/api/segmentChanges/demo?since=-1")
      .to_return(status: 200, body: segments)

    stub_request(:get, "https://sdk.split.io/api/segmentChanges/employees?since=-1")
      .to_return(status: 200, body: segments)
  end

  it 'returns nil when split is nil' do
    expect(subject.split('foo')).to eq(nil)
  end

  it 'returns split when split is not nil' do
    expect(subject.split('test_1_ruby')).to eq(
      name: 'test_1_ruby',
      traffic_type_name: 'user',
      killed: false,
      treatments: %w(on),
      change_number: 1473413807667
    )
  end
end
