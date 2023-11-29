# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Synchronizer do
  subject { SplitIoClient::Engine::Synchronizer }

  let(:splits) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json')) }
  let(:segment1) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json')) }
  let(:segment2) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json')) }
  let(:segment3) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json')) }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:synchronizer) do
    api_key = 'Synchronizer-key'
    runtime_producer = SplitIoClient::Telemetry::RuntimeProducer.new(config)
    flag_sets_repository = SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])
    flag_set_filter = SplitIoClient::Cache::Filter::FlagSetsFilter.new([])
    splits_repository = SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter)
    segments_repository = SplitIoClient::Cache::Repositories::SegmentsRepository.new(config)

    repositories = {
      splits: splits_repository,
      segments: segments_repository,
      impressions: SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config),
      events: SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, runtime_producer)
    }

    parameters = {
      split_fetcher: SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, runtime_producer),
      segment_fetcher: SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, runtime_producer),
      telemetry_runtime_producer: runtime_producer,
      unique_keys_tracker: SplitIoClient::Engine::Impressions::NoopUniqueKeysTracker.new
    }

    subject.new(repositories, config, parameters)
  end

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

    it 'sync_all asynchronous - should return true' do
      result = synchronizer.sync_all

      sleep(2)

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=1470947453878')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
      expect(result).to eq(true)
    end

    it 'sync_all synchronous - should return true' do
      result = synchronizer.sync_all

      sleep(2)

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=-1')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment2?since=1470947453878')).to have_been_made.once
      expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment3?since=-1')).to have_been_made.once
      expect(result).to eq(true)
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

  it 'sync_all synchronous - should return false' do
    stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').to_return(status: 500)

    result = synchronizer.sync_all(false)

    sleep(2)

    expect(result).to eq(false)
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
    synchronizer.stop_periodic_fetch
    config.threads.values.each { |thread| Thread.kill(thread) }
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
