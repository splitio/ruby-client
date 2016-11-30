require 'spec_helper'

describe SplitIoClient do
  subject { SplitIoClient::SplitFactory.new('').manager }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits.json'))) }
  let(:segments) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/segments/engine_segments.json'))) }

  before do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/demo?since=-1')
      .to_return(status: 200, body: segments)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments)
  end

  it 'returns splits' do
    expect(subject.splits).to match_array(
      [
        { name: 'test_1_ruby', traffic_type_name: 'user', killed: false, treatments: ['on'], change_number: 1473413807667 },
        { name: 'sample_feature', traffic_type_name: 'user', killed: false, treatments: ['on'], change_number: 1473325164381 }
      ]
    )
  end

  it 'returns split_names' do
    expect(subject.split_names).to match_array(%w(test_1_ruby sample_feature))
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

  it 'returns split view' do
    expect(subject.build_split_view('foo', subject.split('test_1_ruby'))).to eq(
      { name: 'foo', traffic_type_name: nil, killed: false, treatments: [], change_number: nil }
    )
  end
end
