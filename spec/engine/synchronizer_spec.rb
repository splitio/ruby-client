# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Synchronizer do
  subject { SplitIoClient::Engine::Synchronizer }

  let(:splits) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json')) }
  let(:segment1) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json')) }
  let(:segment2) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json')) }
  let(:segment3) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json')) }

  let(:api_key) { 'api-key-test' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:metrics_repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(config) }
  let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key) }
  let(:sdk_blocker) { SDKBlocker.new(splits_repository, segments_repository, config) }
  let(:metrics) { SplitIoClient::Metrics.new(100, metrics_repository) }
  let(:split_fetcher) { SplitFetcher.new(splits_repository, api_key, metrics, config, sdk_blocker) }
  let(:segment_fetcher) { SegmentFetcher.new(segments_repository, api_key, metrics, config, sdk_blocker) }
  let(:repositories) do
    repos = {}
    repos[:splits] = splits_repository
    repos[:segments] = segments_repository
    repos[:impressions] = impressions_repository
    repos[:metrics] = metrics_repository
    repos[:events] = events_repository
    repos
  end
  let(:parameters) do
    params = {}
    params[:split_fetcher] = split_fetcher
    params[:segment_fetcher] = segment_fetcher

    params
  end
  let(:synchronizer) { subject.new(repositories, api_key, config, sdk_blocker, parameters) }

  before do
    mock_split_changes(splits)
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')
    mock_segment_changes('segment3', segment3, '1470947453879')
  end

  it 'sync_all' do
    synchronizer.sync_all

    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=1470947453878')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=1470947453879')).to have_been_made.once
  end

  it 'start_periodic_data_recording' do
    synchronizer.start_periodic_data_recording

    expect(config.threads.size).to eq(3)
  end

  it 'start_periodic_fetch' do
    synchronizer.start_periodic_fetch

    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=1470947453878')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=1470947453879')).to have_been_made.once
  end
end

private

def mock_split_changes(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
    .to_return(status: 200, body: splits_json)
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
