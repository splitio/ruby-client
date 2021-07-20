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
  let(:event_occupancy) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"timestamp\":1586803930362,\"encoding\":\"json\",\"channel\":\"[?occupancy=metrics.publishers]control_pri\",\"data\":\"{\\\"metrics\\\":{\\\"publishers\\\":2}}\",\"name\":\"[meta]occupancy\"}\n\n\r\n" }

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
  let(:split_fetcher) do
    SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, sdk_blocker, telemetry_runtime_producer)
  end
  let(:segment_fetcher) do
    SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, sdk_blocker, telemetry_runtime_producer)
  end
  let(:notification_manager_keeper) { SplitIoClient::SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer) }
  let(:repositories) do
    {
      splits: splits_repository,
      segments: segments_repository,
      impressions: impressions_repository,
      events: events_repository
    }
  end
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:parameters) do
    {
      split_fetcher: split_fetcher,
      segment_fetcher: segment_fetcher,
      imp_counter: impression_counter,
      telemetry_runtime_producer: telemetry_runtime_producer
    }
  end
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, api_key, config, sdk_blocker, parameters) }

  before do
    mock_split_changes(splits)
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')

    synchronizer.fetch_splits(0)
  end

  context 'SPLIT UPDATE event' do
    it 'must trigger a fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_fetch)
        end

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(sse_handler.sse_client.connected?).to eq(true)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
      end
    end

    it 'must not trigger a fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_update_must_not_fetch)
        end

        splits_repository.set_change_number(1_506_703_262_916)

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(sse_handler.sse_client.connected?).to eq(true)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
      end
    end
  end

  context 'SPLIT KILL event' do
    it 'must trigger a fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_kill_must_fetch)
        end

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        split = splits_repository.get_split('FACUNDO_TEST')
        expect(split[:killed]).to be_truthy
        expect(split[:defaultTreatment]).to eq('on')
        expect(split[:changeNumber]).to eq(1_506_703_262_918)
        expect(sse_handler.sse_client.connected?).to eq(true)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
      end
    end

    it 'must not trigger a fetch.' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_split_kill_must_not_fetch)
        end

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        split = splits_repository.get_split('FACUNDO_TEST')
        expect(split[:killed]).to be_truthy
        expect(split[:defaultTreatment]).to eq('on')
        expect(split[:changeNumber]).to eq(1_506_703_262_916)
        expect(sse_handler.sse_client.connected?).to eq(true)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=1506703262916')).to have_been_made.times(0)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
      end
    end
  end

  context 'SEGMENT UPDATE event' do
    it 'must trigger fetch - with retries' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_segment_update_must_fetch)
        end

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(sse_handler.sse_client.connected?).to eq(true)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.times(12)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
      end
    end

    it 'must not trigger fetch' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_segment_update_must_not_fetch)
        end

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(sse_handler.sse_client.connected?).to eq(true)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment1?since=1470947453877')).to have_been_made.once

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
      end
    end
  end

  context 'OCCUPANCY event' do
    it 'must trigger notification manager keeper' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_content(res, event_occupancy)
        end

        config.streaming_service_url = server.base_uri
        action_event = ''
        sse_handler = subject.new({ config: config, api_key: api_key }, synchronizer, repositories, notification_manager_keeper, telemetry_runtime_producer) do |handler|
          handler.on_action { |action| action_event = action }
        end

        sse_handler.start_workers
        connected = sse_handler.start('token-test', 'channel-test')
        expect(connected).to eq(true)

        sleep(2)

        expect(action_event).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(sse_handler.sse_client.connected?).to eq(true)

        sse_handler.sse_client.close

        expect(sse_handler.sse_client.connected?).to eq(false)
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

def send_content(res, content)
  res.content_type = 'text/event-stream'
  res.status = 200
  res.chunked = true
  rd, wr = IO.pipe
  wr.write(content)
  res.body = rd
  wr.close
  wr
end
