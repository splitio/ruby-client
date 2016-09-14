require 'spec_helper'
require 'pry'

describe SplitIoClient::Cache::Stores::SegmentStore do
  let(:adapter) { SplitIoClient::Cache::Adapters::HashAdapter.new }
  let(:segment_cache) { SplitIoClient::Cache::Segment.new(adapter) }
  let(:split_cache) { SplitIoClient::Cache::Split.new(adapter) }
  let(:config) { SplitIoClient::SplitConfig.new }
  let(:metrics) { SplitIoClient::Metrics.new(100) }
  let(:segment_store) { described_class.new(segment_cache, split_store.splits_cache, config, '', metrics) }
  let(:split_store) { SplitIoClient::Cache::Stores::SplitStore.new(split_cache, config, '', metrics) }
  let(:segments_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/segments.json'))) }
  let(:segments_json2) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/segments2.json'))) }
  let(:splits_with_segments_json) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/splits3.json'))) }
  let(:segment_data) do
    [
      { name: "employees", added: ["max", "dan"], removed: [], since: -1, till: 1473863075059},
      { name: "employees", added: [], :removed=>[], since: 1473863075059, till: 1473863075059}
    ]
  end

  before do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
      .to_return(status: 200, body: segments_json)

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=1473863075059')
      .to_return(status: 200, body: segments_json2)

    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body: splits_with_segments_json)
  end

  it 'returns segments by names' do
    segments = segment_store.send(:segments_by_names, ['employees'])

    expect(segments).to eq(segment_data)
  end

  it 'returns used segments names' do
    split_store.send(:store_splits)

    expect(split_store.splits_cache.used_segments_names).to eq(%w(employees))
  end

  it 'stores segments' do
    split_store.send(:store_splits)
    segment_store.send(:store_segments)

    expect(segment_store.segment_cache['segments'].size).to eq(2)
  end

  it 'updates added/removed' do
    segments = segment_store.send(:segments_api).send(:fetch_segments, 'employees', '', -1)
    expect(segments.first[:added]).to eq(%w(max dan))
    expect(segments.first[:removed]).to eq([])

    segments = segment_store.send(:segments_api).send(:fetch_segments, 'employees', '', 1473863075059)
    expect(segments.first[:added]).to eq([])
    expect(segments.first[:removed]).to eq([])
  end
end
