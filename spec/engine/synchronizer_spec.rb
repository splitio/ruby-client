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
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, runtime_producer) }
  let(:sdk_blocker) { SplitIoClient::Cache::Stores::SDKBlocker.new(splits_repository, segments_repository, config) }
  let(:split_fetcher) do
    SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, sdk_blocker, runtime_producer)
  end
  let(:segment_fetcher) do
    SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, sdk_blocker, runtime_producer)
  end
  let(:repositories) do
    repos = {}
    repos[:splits] = splits_repository
    repos[:segments] = segments_repository
    repos[:impressions] = impressions_repository
    repos[:events] = events_repository
    repos
  end
  let(:parameters) do
    params = {}
    params[:split_fetcher] = split_fetcher
    params[:segment_fetcher] = segment_fetcher
    params[:telemetry_runtime_producer] = runtime_producer

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

      sleep(2)

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=1470947453878')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
    end

    it 'start_periodic_data_recording' do
      synchronizer.start_periodic_data_recording

      expect(config.threads.size).to eq(4)
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
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')

    synchronizer.fetch_splits(0)
    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
  end

  it 'fetch_splits - with CDN bypassed' do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
      .to_return(status: 200, body:
    '{
      "splits": [],
      "since": -1,
      "till": 1506703262918
    }')

    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918')
      .to_return(status: 200, body:
    '{
      "splits": [],
      "since": 1506703262918,
      "till": 1506703262918
    }')

    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918&till=1506703262920')
      .to_return(status: 200, body:
    '{
      "splits": [],
      "since": 1506703262918,
      "till": 1506703262921
    }')

    synchronizer.fetch_splits(1_506_703_262_920)

    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918')).to have_been_made.times(9)
    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918&till=1506703262920')).to have_been_made.once
  end

  it 'fetch_segment' do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')
      .to_return(status: 200, body:
    '{
      "name": "segment3",
      "added": [],
      "removed": [],
      "since": -1,
      "till": 111333
    }')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111333')
      .to_return(status: 200, body:
    '{
      "name": "segment3",
      "added": [],
      "removed": [],
      "since": 111333,
      "till": 111333
    }')

    synchronizer.fetch_segment('segment3', 111_222)
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111333')).to have_been_made.once
  end

  it 'fetch_segment - with CDN bypassed' do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')
      .to_return(status: 200, body:
    '{
      "name": "segment3",
      "added": [],
      "removed": [],
      "since": -1,
      "till": 111333
    }')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111333')
      .to_return(status: 200, body:
    '{
      "name": "segment3",
      "added": [],
      "removed": [],
      "since": 111333,
      "till": 111333
    }')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111333&till=111555')
      .to_return(status: 200, body:
    '{
      "name": "segment3",
      "added": [],
      "removed": [],
      "since": 111555,
      "till": 111555
    }')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111555&till=111555')
      .to_return(status: 200, body:
    '{
      "name": "segment3",
      "added": [],
      "removed": [],
      "since": 111555,
      "till": 111555
    }')

    synchronizer.fetch_segment('segment3', 111_555)
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111333')).to have_been_made.times(10)
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111333&till=111555')).to have_been_made.once
    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=111555&till=111555')).to have_been_made.once
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
