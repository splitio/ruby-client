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
  let(:sdk_blocker) { SplitIoClient::Cache::Stores::SDKBlocker.new(splits_repository, segments_repository, config) }
  let(:metrics) { SplitIoClient::Metrics.new(100, metrics_repository) }
  let(:split_fetcher) do
    SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, metrics, config, sdk_blocker)
  end
  let(:segment_fetcher) do
    SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, metrics, config, sdk_blocker)
  end
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

  context 'tests with mock data' do
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
    end
  end

  it 'fetch_splits' do
    mock_split_changes(splits)

    synchronizer.fetch_splits
    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
  end

  it 'fetch_splits with retries' do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return({ status: 500 }, { status: 200, body: splits })

    synchronizer.fetch_splits

    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.times(2)
  end

  it 'fetch_segment' do
    mock_segment_changes('segment3', segment3, '-1')

    synchronizer.fetch_segment('segment3')
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
  end

  it 'fetch_segment with retries' do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')
      .to_return({ status: 500 }, { status: 200, body: segment3 })

    synchronizer.fetch_segment('segment3')
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.times(2)
  end
end

private

def mock_split_changes(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').to_return(status: 200, body: splits_json)
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
