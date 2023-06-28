# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::EventSource::Client do
  subject { SplitIoClient::SSE::EventSource::Client }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:telemetry_runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
  let(:api_token) { 'api-token-test' }
  let(:api_key) { 'client-spec-key' }
  let(:event_parser) { SplitIoClient::SSE::EventSource::EventParser.new(config) }
  let(:repositories) do
    {
      splits: SplitIoClient::Cache::Repositories::SplitsRepository.new(config),
      segments: SplitIoClient::Cache::Repositories::SegmentsRepository.new(config),
      impressions: SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config),
      events: SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, telemetry_runtime_producer)
    }
  end
  let(:parameters) do
    {
      split_fetcher: SplitIoClient::Cache::Fetchers::SplitFetcher.new(repositories[:splits], api_key, config, telemetry_runtime_producer),
      segment_fetcher: SplitIoClient::Cache::Fetchers::SegmentFetcher.new(repositories[:segments], api_key, config, telemetry_runtime_producer),
      imp_counter: SplitIoClient::Engine::Common::ImpressionCounter.new,
      telemetry_runtime_producer: telemetry_runtime_producer
    }
  end
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, config, parameters) }
  let(:splits_worker) { SplitIoClient::SSE::Workers::SplitsWorker.new(synchronizer, config, repositories[:splits], telemetry_runtime_producer) }
  let(:segments_worker) { SplitIoClient::SSE::Workers::SegmentsWorker.new(synchronizer, config, repositories[:segments]) }
  let(:push_status_queue) { Queue.new }
  let(:notification_manager_keeper) { SplitIoClient::SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer, push_status_queue) }
  let(:notification_processor) { SplitIoClient::SSE::NotificationProcessor.new(config, splits_worker, segments_worker) }

  let(:event_split_update) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 5564531221, \\\"defaultTreatment\\\" : \\\"off\\\", \\\"splitName\\\" : \\\"split-test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": 5564531221, \\\"segmentName\\\" : \\\"segment-test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_control) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"CONTROL\\\", \\\"controlType\\\" : \\\"control-type-example\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_invalid_format) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"content\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_occupancy) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"timestamp\":1586803930362,\"encoding\":\"json\",\"channel\":\"[?occupancy=metrics.publishers]control_pri\",\"data\":\"{\\\"metrics\\\":{\\\"publishers\\\":2}}\",\"name\":\"[meta]occupancy\"}\n\n\r\n" }
  let(:event_error) { "d4\r\nevent: error\ndata: {\"message\":\"Token expired\",\"code\":40142,\"statusCode\":401,\"href\":\"https://help.ably.io/error/40142\"}" }

  context 'tests' do
    it 'receive split update event' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .with(headers: { 'Authorization' => 'Bearer client-spec-key' })
        .to_return(status: 200, body: '{"splits":[],"since":-1,"till":5564531221}')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=5564531221')
        .with(headers: { 'Authorization' => 'Bearer client-spec-key' })
        .to_return(status: 200, body: '{"splits":[],"since":5564531221,"till":5564531221}')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_split_update)
        end
        start_workers

        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(true)
        expect(sse_client.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        sleep 1
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(1)

        sse_client.close

        expect(sse_client.connected?).to eq(false)

        stop_workers
      end
    end

    it 'receive split kill event' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .with(headers: { 'Authorization' => 'Bearer client-spec-key' })
        .to_return(status: 200, body: '{"splits":[],"since":-1,"till":5564531221}')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=5564531221')
        .with(headers: { 'Authorization' => 'Bearer client-spec-key' })
        .to_return(status: 200, body: '{"splits":[],"since":5564531221,"till":5564531221}')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_split_kill)
        end
        start_workers

        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(true)
        expect(sse_client.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        sleep 1
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(1)

        sse_client.close

        expect(sse_client.connected?).to eq(false)
        stop_workers
      end
    end

    it 'receive segment update event' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment-test?since=-1')
        .with(headers: { 'Authorization' => 'Bearer client-spec-key' })
        .to_return(status: 200, body: '{"name":"segment-test","added":[],"removed":[],"since":-1,"till":5564531221}')
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/segment-test?since=5564531221')
        .with(headers: { 'Authorization' => 'Bearer client-spec-key' })
        .to_return(status: 200, body: '{"name":"segment-test","added":[],"removed":[],"since":5564531221,"till":5564531221}')

      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_segment_update)
        end
        start_workers
        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(true)
        expect(sse_client.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        sleep 0.5
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment-test?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(1)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment-test?since=5564531221').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(1)

        sse_client.close

        expect(sse_client.connected?).to eq(false)
        stop_workers
      end
    end

    it 'receive control event' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_control)
        end
        start_workers
        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(true)
        expect(sse_client.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(0)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment-test?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(0)

        sse_client.close

        expect(sse_client.connected?).to eq(false)
        stop_workers
      end
    end

    it 'receive invalid format' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_invalid_format)
        end
        start_workers
        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(true)
        expect(sse_client.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
        expect(a_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(0)
        expect(a_request(:get, 'https://sdk.split.io/api/segmentChanges/segment-test?since=-1').with(headers: { 'Authorization' => 'Bearer client-spec-key' })).to have_been_made.times(0)

        sse_client.close

        expect(sse_client.connected?).to eq(false)
        stop_workers
      end
    end

    it 'receive occupancy event' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_occupancy)
        end
        start_workers
        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(true)
        expect(sse_client.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)

        sse_client.close

        expect(sse_client.connected?).to eq(false)
        stop_workers
      end
    end

    it 'receive error event' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_error, 400)
        end
        start_workers
        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)

        expect(connected).to eq(false)
        expect(sse_client.connected?).to eq(false)
        expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

        stop_workers
      end
    end

    it 'first event - when server return 400' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_stream_content(res, event_error, 400)
        end
        start_workers
        sse_client = subject.new(config, api_token, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue)

        connected = sse_client.start(server.base_uri)
        expect(connected).to eq(false)
        expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

        stop_workers
      end
    end
  end

  private

  def start_workers
    splits_worker.start
    segments_worker.start
  end

  def stop_workers
    splits_worker.stop
    segments_worker.stop
  end

  def send_stream_content(res, content, status = 200)
    res.content_type = 'text/event-stream'
    res.status = status
    res.chunked = true
    rd, wr = IO.pipe
    wr.write(content)
    res.body = rd
    wr.close
    wr
  end
end
