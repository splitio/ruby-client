# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::Workers::SplitsWorker do
  subject { SplitIoClient::SSE::Workers::SplitsWorker }

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
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, telemetry_runtime_producer) }
  let(:sdk_blocker) { SplitIoClient::Cache::Stores::SDKBlocker.new(splits_repository, segments_repository, config) }  
  let(:split_fetcher) { SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, sdk_blocker, telemetry_runtime_producer) }
  let(:segment_fetcher) { SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, sdk_blocker, telemetry_runtime_producer) }
  let(:repositories) { { splits: splits_repository, segments: segments_repository } }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:params) { { split_fetcher: split_fetcher, segment_fetcher: segment_fetcher, imp_counter: impression_counter, telemetry_runtime_producer: telemetry_runtime_producer } }
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, api_key, config, sdk_blocker, params) }

  it 'add change number - must tigger fetcch - with retries' do
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

    worker = subject.new(synchronizer, config, splits_repository)
    worker.start
    worker.add_to_queue(1_506_703_262_919)

    sleep(1)

    expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262918')).to have_been_made.times(10)
  end

  context 'add change number to queue' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')

      split_fetcher.fetch_splits
    end

    it 'must trigger fetch' do
      worker = subject.new(synchronizer, config, splits_repository)
      worker.start
      worker.add_to_queue(1_506_703_262_918)

      sleep(1)

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.once
    end

    it 'must not trigger fetch' do
      worker = subject.new(synchronizer, config, splits_repository)
      worker.start
      worker.add_to_queue(1_506_703_262_916)

      sleep(1)

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end

    it 'without start, must not fetch' do
      worker = subject.new(synchronizer, config, splits_repository)

      worker.add_to_queue(1_506_703_262_918)

      sleep(1)

      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end
  end

  context 'kill split notification' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')

      split_fetcher.fetch_splits
    end

    it 'must kill split and trigger fetch' do
      worker = subject.new(synchronizer, config, splits_repository)

      worker.start
      worker.kill_split(1_506_703_262_918, 'FACUNDO_TEST', 'on')

      sleep(1)

      split = splits_repository.get_split('FACUNDO_TEST')
      expect(split[:killed]).to be_truthy
      expect(split[:defaultTreatment]).to eq('on')
      expect(split[:changeNumber]).to eq(1_506_703_262_918)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.once
    end

    it 'must kill split and must not trigger fetch' do
      worker = subject.new(synchronizer, config, splits_repository)

      worker.start
      worker.kill_split(1_506_703_262_916, 'FACUNDO_TEST', 'on')

      sleep(1)

      split = splits_repository.get_split('FACUNDO_TEST')
      expect(split[:killed]).to be_truthy
      expect(split[:defaultTreatment]).to eq('on')
      expect(split[:changeNumber]).to eq(1_506_703_262_916)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end

    it 'without start, must not fetch ' do
      worker = subject.new(synchronizer, config, splits_repository)

      worker.kill_split(1_506_703_262_918, 'FACUNDO_TEST', 'on')

      sleep(1)

      split = splits_repository.get_split('FACUNDO_TEST')
      expect(split[:killed]).to eq(false)
      expect(split[:defaultTreatment]).to eq('off')
      expect(split[:changeNumber]).to eq(1_506_703_262_916)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)
    end
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
