# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::Workers::SegmentsWorker do
  subject { SplitIoClient::SSE::Workers::SegmentsWorker }

  let(:splits) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json')) }
  let(:segment1) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json')) }
  let(:segment2) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json')) }
  let(:segment3) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json')) }
  let(:api_key) { 'SegmentsWorker-key' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::FlagSetsRepository.new([])}
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([])}
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, telemetry_runtime_producer) }
  let(:split_fetcher) { SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, telemetry_runtime_producer) }
  let(:segment_fetcher) { SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, telemetry_runtime_producer) }
  let(:repositories) { { splits: splits_repository, segments: segments_repository } }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:params) { { split_fetcher: split_fetcher, segment_fetcher: segment_fetcher, imp_counter: impression_counter, telemetry_runtime_producer: telemetry_runtime_producer } }
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, config, params) }

  before do
    mock_split_changes(splits)
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')

    split_fetcher.fetch_splits
    segment_fetcher.fetch_segments
  end

  it 'must trigger fetch' do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')
      .to_return(status: 200, body: '{"name": "segment1","added": [],"removed": [],"since": 1470947453878,"till": 1470947453878}')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453878')
      .to_return(status: 200, body: '{"name": "segment1","added": [],"removed": [],"since": 1470947453878,"till": 1470947453878}')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453878&till=1506703262918')
      .to_return(status: 200, body: '{"name": "segment1","added": [],"removed": [],"since": 1506703262918,"till": 1506703262918}')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1506703262918&till=1506703262918')
      .to_return(status: 200, body: '{"name": "segment1","added": [],"removed": [],"since": 1506703262918,"till": 1506703262918}')

    worker = subject.new(synchronizer, config, segments_repository)
    worker.start
    worker.add_to_queue(1_506_703_262_918, 'segment1')

    sleep 1

    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.times(2)
  end

  it 'must trigger fetch - with retries' do
    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877&till=1506703262918')
      .to_return(status: 200, body: '{"name": "segment1","added": [],"removed": [],"since": 1506703262918,"till": 1506703262918}')

    stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1506703262918&till=1506703262918')
      .to_return(status: 200, body: '{"name": "segment1","added": [],"removed": [],"since": 1506703262918,"till": 1506703262918}')

    worker = subject.new(synchronizer, config, segments_repository)
    worker.start
    worker.add_to_queue(1_506_703_262_918, 'segment1')

    sleep 1

    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.times(11)
  end

  it 'must not trigger fetch' do
    worker = subject.new(synchronizer, config, segments_repository)

    worker.start
    worker.add_to_queue(1_470_947_453_877, 'segment1')

    sleep 1

    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.times(1)
  end

  it 'try to add without start woker, must not adde to queue' do
    worker = subject.new(synchronizer, config, segments_repository)

    worker.add_to_queue(1_470_947_453_877, 'segment1')

    sleep 1

    expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.times(1)
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
end
