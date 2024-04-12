# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::SSEHandler do
  subject { SplitIoClient::SSE::SSEHandler }

  let(:request_decorator) { SplitIoClient::Api::RequestDecorator.new(nil) }
  let(:api_key) { 'SSEHandler-key' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])}
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([])}
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:push_status_queue) { Queue.new }
  let(:notification_manager_keeper) { SplitIoClient::SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer, push_status_queue) }
  let(:repositories) do
    {
      splits: splits_repository,
      segments: segments_repository,
      impressions: SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config),
      events: SplitIoClient::Cache::Repositories::EventsRepository.new(config, api_key, telemetry_runtime_producer, request_decorator)
    }
  end
  let(:parameters) do
    {
      split_fetcher: SplitIoClient::Cache::Fetchers::SplitFetcher.new(splits_repository, api_key, config, telemetry_runtime_producer, request_decorator),
      segment_fetcher: SplitIoClient::Cache::Fetchers::SegmentFetcher.new(segments_repository, api_key, config, telemetry_runtime_producer, request_decorator),
      imp_counter: SplitIoClient::Engine::Common::ImpressionCounter.new,
      telemetry_runtime_producer: telemetry_runtime_producer
    }
  end
  let(:synchronizer) { SplitIoClient::Engine::Synchronizer.new(repositories, config, parameters) }
  let(:splits_worker) { SplitIoClient::SSE::Workers::SplitsWorker.new(synchronizer, config, splits_repository, telemetry_runtime_producer, parameters[:segment_fetcher]) }
  let(:segments_worker) { SplitIoClient::SSE::Workers::SegmentsWorker.new(synchronizer, config, segments_repository) }
  let(:notification_processor) { SplitIoClient::SSE::NotificationProcessor.new(config, splits_worker, segments_worker) }
  let(:event_parser) { SplitIoClient::SSE::EventSource::EventParser.new(config) }
  let(:sse_client) { SplitIoClient::SSE::EventSource::Client.new(config, api_key, telemetry_runtime_producer, event_parser, notification_manager_keeper, notification_processor, push_status_queue, request_decorator) }

  it 'start - should connect' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_content(res, '')
      end

      config.streaming_service_url = server.base_uri
      sse_handler = subject.new(config, splits_worker, segments_worker, sse_client)

      connected = sse_handler.start('token-test', 'channel-test')
      expect(connected).to eq(true)
      expect(sse_handler.connected?).to eq(true)
      expect(push_status_queue.pop).to eq(SplitIoClient::Constants::PUSH_CONNECTED)

      sse_handler.stop

      expect(sse_handler.connected?).to eq(false)
      expect(sse_handler.sse_client.connected?).to eq(false)
      expect(push_status_queue.pop).to eq(SplitIoClient::Constants::PUSH_FORCED_STOP)
    end
  end

  it 'start - should not connect' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_content(res, '')
      end

      sse_handler = subject.new(config, splits_worker, segments_worker, sse_client)

      connected = sse_handler.start('token-test', 'channel-test')
      expect(connected).to eq(false)
      expect(sse_handler.connected?).to eq(false)
      expect(sse_handler.sse_client.connected?).to eq(false)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

      sse_handler.stop
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)
    end
  end

  private

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
