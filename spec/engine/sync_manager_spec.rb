# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::Engine::SyncManager do
  subject { SplitIoClient::Engine::SyncManager }

  let(:event_control) { "d4\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"timestamp\": 1582056812285,\"encoding\": \"json\",\"channel\": \"control_pri\",\"data\":\"{\\\"type\\\" : \\\"CONTROL\\\",\\\"controlType\\\":\\\"STREAMING_DISABLED\\\"}\"}\n\n\r\n" }

  let(:splits) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json')) }
  let(:segment1) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json')) }
  let(:segment2) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json')) }
  let(:segment3) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json')) }
  let(:body_response) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/auth_body_response.json')) }
  let(:api_key) { 'SyncManager-key' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), streaming_enabled: true) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, telemetry_runtime_producer) }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:repositories) do
    {
      splits: splits_repository,
      segments: segments_repository,
      impressions: impressions_repository,
      events: events_repository
    }
  end
  let(:sync_params) do
    {
      split_fetcher: SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, telemetry_runtime_producer),
      segment_fetcher: SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, telemetry_runtime_producer),
      imp_counter: impression_counter,
      telemetry_runtime_producer: telemetry_runtime_producer,
      unique_keys_tracker: SplitIoClient::Engine::Impressions::NoopUniqueKeysTracker.new
    }
  end
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, config, sync_params) }
  let(:init_producer) { SplitIoClient::Telemetry::InitProducer.new(config) }
  let(:init_consumer) { SplitIoClient::Telemetry::InitConsumer.new(config) }
  let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
  let(:evaluation_consumer) { SplitIoClient::Telemetry::EvaluationConsumer.new(config) }
  let(:telemetry_consumers) { { init: init_consumer, runtime: runtime_consumer, evaluation: evaluation_consumer } }
  let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, telemetry_runtime_producer) }
  let(:telemetry_synchronizer) { SplitIoClient::Telemetry::Synchronizer.new(config, telemetry_consumers, init_producer, repositories, telemetry_api) }
  let(:status_manager) { SplitIoClient::Engine::StatusManager.new(config) }
  let(:splits_worker) { SplitIoClient::SSE::Workers::SplitsWorker.new(synchronizer, config, splits_repository, telemetry_runtime_producer) }
  let(:segments_worker) { SplitIoClient::SSE::Workers::SegmentsWorker.new(synchronizer, config, segments_repository) }
  let(:notification_processor) { SplitIoClient::SSE::NotificationProcessor.new(config, splits_worker, segments_worker) }
  let(:event_parser) { SplitIoClient::SSE::EventSource::EventParser.new(config) }
  let(:push_status_queue) { Queue.new }
  let(:notification_manager_keeper) { SplitIoClient::SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer, push_status_queue) }
  let(:sse_client) { SplitIoClient::SSE::EventSource::Client.new(config, api_key, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue) }
  let(:sse_handler) { SplitIoClient::SSE::SSEHandler.new(config, splits_worker, segments_worker, sse_client) }
  let(:push_manager) { SplitIoClient::Engine::PushManager.new(config, sse_handler, api_key, telemetry_runtime_producer) }

  before do
    mock_split_changes_with_since(splits, '-1')
    mock_split_changes_with_since(splits, '1506703262916')
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')
    stub_request(:get, config.auth_service_url).to_return(status: 200, body: body_response)
    stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config').to_return(status: 200, body: '')
  end

  it 'start sync manager with success sse connection.' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_content(res, 'content')
      end

      config.streaming_service_url = server.base_uri

      sync_manager = subject.new(config, synchronizer, telemetry_runtime_producer, telemetry_synchronizer, status_manager, sse_handler, push_manager, push_status_queue)
      sync_manager.start

      sleep(2)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once

      expect(config.threads.size).to eq(11)
    end
  end

  it 'start sync manager with wrong sse host url and non connect to server, must start polling.' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_content(res, 'content')
      end

      config.streaming_service_url = 'https://fake-sse.io'
      config.connection_timeout = 1

      sync_manager = subject.new(config, synchronizer, telemetry_runtime_producer, telemetry_synchronizer, status_manager, sse_handler, push_manager, push_status_queue)
      sync_manager.start

      sleep(2)
      expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')).to have_been_made.once

      expect(config.threads.size).to eq(8)
    end
  end

  it 'start sync manager receiving control message, must switch to polling' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_content(res, event_control)
      end

      config.streaming_service_url = server.base_uri

      sync_manager = subject.new(config, synchronizer, telemetry_runtime_producer, telemetry_synchronizer, status_manager, sse_handler, push_manager, push_status_queue)
      sync_manager.start

      sleep(2)
      config.threads.select { |name, _| name.to_s.end_with? 'worker' }.values.each do |thread|
        expect(thread.status).to eq(false) # Status fasle: when this thread is terminated normally as expected
      end

      sse_handler = sync_manager.instance_variable_get(:@sse_handler)
      expect(sse_handler.connected?).to eq(false)
    end
  end

  private

  def mock_split_changes_with_since(splits_json, since)
    stub_request(:get, "https://sdk.split.io/api/splitChanges?since=#{since}")
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
end
