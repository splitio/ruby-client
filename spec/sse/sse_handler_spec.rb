# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::SSEHandler do
  subject { SplitIoClient::SSE::SSEHandler }

  let(:event_split_update_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1506703262918}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_update_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 1506703262916}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 1506703262918, \\\"defaultTreatment\\\" : \\\"on\\\", \\\"splitName\\\" : \\\"FACUNDO_TEST\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 1506703262916, \\\"defaultTreatment\\\" : \\\"on\\\", \\\"splitName\\\" : \\\"FACUNDO_TEST\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update_must_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": 1470947453879, \\\"segmentName\\\" : \\\"segment1\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update_must_not_fetch) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": 1470947453877, \\\"segmentName\\\" : \\\"segment1\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }

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
  let(:adapter) { SplitIoClient::SplitAdapter.new(api_key, splits_repository, segments_repository, impressions_repository, metrics_repository, events_repository, sdk_blocker, config) }
  let(:splits_worker) { SplitIoClient::SSE::Workers::SplitsWorker.new(adapter.split_fetcher, config, splits_repository) }
  let(:segments_worker) { SplitIoClient::SSE::Workers::SegmentsWorker.new(adapter.segment_fetcher, config, segments_repository) }
  let(:control_worker) { SplitIoClient::SSE::Workers::ControlWorker.new(config) }

  before do
    mock_split_changes(splits)
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')
    mock_segment_changes('segment3', segment3, '1470947453879')

    splits_worker.start
    segments_worker.start
    control_worker.start
  end

  context 'SPLIT UPDATE event' do
    it 'must trigger a fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_fetch, keep_open: false)
        end

        sse_handler = subject.new(config, splits_worker, segments_worker, control_worker)
        sse_handler.start(server.base_uri, 'token-test', 'channel-test')
        sleep(0.2)

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.once

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::DISCONNECTED)
      end
    end

    it 'must not trigger a fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_not_fetch, keep_open: false)
        end

        sse_handler = subject.new(config, splits_worker, segments_worker, control_worker)
        sse_handler.start(server.base_uri, 'token-test', 'channel-test')
        sleep(0.2)

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::DISCONNECTED)
      end
    end
  end

  context 'SPLIT KILL event' do
    it 'must trigger a fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_kill_must_fetch, keep_open: false)
        end

        sse_handler = subject.new(config, splits_worker, segments_worker, control_worker)
        sse_handler.start(server.base_uri, 'token-test', 'channel-test')
        sleep(0.2)

        split = splits_repository.get_split('FACUNDO_TEST')
        expect(split[:killed]).to be_truthy
        expect(split[:defaultTreatment]).to eq('on')
        expect(split[:changeNumber]).to eq(1_506_703_262_918)
        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.once

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::DISCONNECTED)
      end
    end

    it 'must not trigger a fetch.' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_kill_must_not_fetch, keep_open: false)
        end

        sse_handler = subject.new(config, splits_worker, segments_worker, control_worker)
        sse_handler.start(server.base_uri, 'token-test', 'channel-test')
        sleep(0.2)

        split = splits_repository.get_split('FACUNDO_TEST')
        expect(split[:killed]).to be_truthy
        expect(split[:defaultTreatment]).to eq('on')
        expect(split[:changeNumber]).to eq(1_506_703_262_916)
        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::DISCONNECTED)
      end
    end
  end

  context 'SEGMENT UPDATE event' do
    it 'must trigger fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_segment_update_must_fetch, keep_open: false)
        end

        sse_handler = subject.new(config, splits_worker, segments_worker, control_worker)
        sse_handler.start(server.base_uri, 'token-test', 'channel-test')
        sleep(0.2)

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.times(2)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::DISCONNECTED)
      end
    end

    it 'must not trigger fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_segment_update_must_not_fetch, keep_open: false)
        end

        sse_handler = subject.new(config, splits_worker, segments_worker, control_worker)
        sse_handler.start(server.base_uri, 'token-test', 'channel-test')
        sleep(0.2)

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.status).to eq(SplitIoClient::SSE::EventSource::Status::DISCONNECTED)
      end
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

def send_content(res, content, keep_open:)
  res.content_type = 'text/event-stream'
  res.status = 200
  res.chunked = true
  rd, wr = IO.pipe
  wr.write(content)
  res.body = rd
  wr.close unless keep_open
  wr
end
