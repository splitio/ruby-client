# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::Engine::PushManager do
  subject { SplitIoClient::Engine::PushManager }

  let(:body_response) { File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/auth_body_response.json')) }
  let(:api_key) { 'PushManager-key' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([]) }
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([]) }
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:split_fetcher) { SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, runtime_producer) }
  let(:segment_fetcher) { SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, runtime_producer) }
  let(:splits_worker) { SplitIoClient::SSE::Workers::SplitsWorker.new(split_fetcher, config, splits_repository, runtime_producer, segment_fetcher) }
  let(:segments_worker) { SplitIoClient::SSE::Workers::SegmentsWorker.new(segment_fetcher, config, segments_repository) }
  let(:push_status_queue) { Queue.new }
  let(:notification_manager_keeper) { SplitIoClient::SSE::NotificationManagerKeeper.new(config, runtime_producer, push_status_queue) }
  let(:repositories) { { splits: splits_repository, segments: segments_repository } }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:params) do
    {
      split_fetcher: split_fetcher,
      segment_fetcher: segment_fetcher,
      imp_counter: impression_counter,
      telemetry_runtime_producer: runtime_producer
    }
  end
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, config, params) }
  let(:event_parser) { SplitIoClient::SSE::EventSource::EventParser.new(config) }
  let(:notification_processor) { SplitIoClient::SSE::NotificationProcessor.new(config, splits_worker, segments_worker) }
  let(:sse_client) { SplitIoClient::SSE::EventSource::Client.new(config, api_key, runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue) }

  context 'start_sse' do
    it 'must connect to server' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_mock_content(res, 'content')
        end

        stub_request(:get, config.auth_service_url + "?s=1.1").to_return(status: 200, body: body_response)
        config.streaming_service_url = server.base_uri

        sse_handler = SplitIoClient::SSE::SSEHandler.new(config, splits_worker, segments_worker, sse_client)

        push_manager = subject.new(config, sse_handler, api_key, runtime_producer)
        connected = push_manager.start_sse

        expect(a_request(:get, config.auth_service_url + "?s=1.1")).to have_been_made.times(1)

        sleep(1.5)
        expect(connected).to eq(true)
        expect(sse_handler.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)
      end
    end

    it 'must not connect to server. Auth server return 500' do
      stub_request(:get, config.auth_service_url + "?s=1.1").to_return(status: 500)

      sse_handler = SplitIoClient::SSE::SSEHandler.new(config, splits_worker, segments_worker, sse_client)

      push_manager = subject.new(config, sse_handler, api_key, runtime_producer)
      connected = push_manager.start_sse

      expect(a_request(:get, config.auth_service_url + "?s=1.1")).to have_been_made.times(1)

      sleep(1.5)

      expect(connected).to eq(false)
      expect(sse_handler.connected?).to eq(false)
    end

    it 'must not connect to server. Auth server return 401' do
      stub_request(:get, config.auth_service_url + "?s=1.1").to_return(status: 401)

      sse_handler = SplitIoClient::SSE::SSEHandler.new(config, splits_worker, segments_worker, sse_client)

      push_manager = subject.new(config, sse_handler, api_key, runtime_producer)
      connected = push_manager.start_sse

      expect(a_request(:get, config.auth_service_url + "?s=1.1")).to have_been_made.times(1)

      sleep(1.5)

      expect(connected).to eq(false)
      expect(sse_handler.connected?).to eq(false)
    end
  end

  context 'stop_sse' do
    it 'must disconnect from the server' do
      mock_server do |server|
        server.setup_response('/') do |_, res|
          send_mock_content(res, 'content')
        end

        stub_request(:get, config.auth_service_url + "?s=1.1").to_return(status: 200, body: body_response)
        config.streaming_service_url = server.base_uri

        sse_handler = SplitIoClient::SSE::SSEHandler.new(config, splits_worker, segments_worker, sse_client)
        push_manager = subject.new(config, sse_handler, api_key, runtime_producer)
        connected = push_manager.start_sse

        expect(a_request(:get, config.auth_service_url + "?s=1.1")).to have_been_made.times(1)

        sleep(1.5)

        expect(connected).to eq(true)
        expect(sse_handler.connected?).to eq(true)
        expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_CONNECTED)

        push_manager.stop_sse

        expect(sse_handler.connected?).to eq(false)
      end
    end
  end
end

def send_mock_content(res, content)
  res.content_type = 'text/event-stream'
  res.status = 200
  res.chunked = true
  rd, wr = IO.pipe
  wr.write(content)
  res.body = rd
  wr.close
  wr
end
