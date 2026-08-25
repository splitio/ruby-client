# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

# Regression coverage for FME-18143: an SSE reconnect storm that leaked one
# connect_stream thread per reconnect and eventually OOM-killed the container.
#
# Two defects are covered here:
#   1. close() was reported to SyncManager as PUSH_RETRYABLE_ERROR, so an intentional
#      teardown asked for a reconnect, whose teardown asked for another one.
#   2. connect_stream threads shared @socket/@connected/@first_event and were stored in
#      a single overwritten handle, so a superseded thread kept running forever on the
#      next connection's socket.
describe 'FME-18143 SSE reconnect storm' do
  let(:log) { StringIO.new }
  let(:events_queue) { Queue.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), debug_enabled: false) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:api_token) { 'api-token-test' }
  let(:event_parser) { SplitIoClient::SSE::EventSource::EventParser.new(config) }
  let(:push_status_queue) { Queue.new }
  let(:notification_manager_keeper) do
    SplitIoClient::SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer, push_status_queue)
  end
  let(:notification_processor) { double(process: true) }

  let(:keepalive) { "c\r\n:keepalive\n\n\r\n" }

  def sse_client
    @sse_client ||= SplitIoClient::SSE::EventSource::Client.new(
      config, api_token, telemetry_runtime_producer, event_parser,
      notification_manager_keeper, notification_processor, push_status_queue
    )
  end

  # Serves an SSE stream that keeps dribbling keepalives, so a live reader always has
  # something to consume and will not exit just because the server went quiet.
  def serve_stream(server)
    server.setup_response('/') do |_, res|
      res.content_type = 'text/event-stream'
      res.status = 200
      res.chunked = true
      rd, wr = IO.pipe
      wr.write(keepalive)
      res.body = rd
      Thread.new do
        20.times do
          sleep 0.5
          begin
            wr.write(keepalive)
          rescue StandardError
            break
          end
        end
        begin
          wr.close
        rescue StandardError
          nil
        end
      end
    end
  end

  def drain(queue)
    statuses = []
    statuses << queue.pop(true) until queue.empty?
    statuses
  rescue ThreadError
    statuses
  end

  it 'does not report an intentional close as a retryable error' do
    mock_server do |server|
      serve_stream(server)

      expect(sse_client.start(server.base_uri)).to eq(true)
      sse_client.close
      sleep 1

      statuses = drain(push_status_queue)
      expect(statuses).to include(SplitIoClient::Constants::PUSH_CONNECTED)
      expect(statuses).not_to include(SplitIoClient::Constants::PUSH_RETRYABLE_ERROR)
    end
  end

  it 'does not manufacture retryable errors across repeated close/start cycles' do
    mock_server do |server|
      serve_stream(server)

      cycles = 15
      cycles.times do
        sse_client.start(server.base_uri)
        sse_client.close
      end
      sleep 1

      statuses = drain(push_status_queue)
      retryable = statuses.count(SplitIoClient::Constants::PUSH_RETRYABLE_ERROR)
      expect(retryable).to eq(0), "#{retryable} spurious PUSH_RETRYABLE_ERROR out of #{cycles} intentional closes"
    end
  end

  it 'terminates the previous connect_stream thread when reconnecting' do
    mock_server do |server|
      serve_stream(server)

      spawned = []
      10.times do
        sse_client.start(server.base_uri)
        thread = config.threads[:connect_stream]
        spawned << thread unless thread.nil? || spawned.include?(thread)
        sse_client.close
      end

      sleep 2
      leaked = spawned.reject { |t| t == config.threads[:connect_stream] }.select(&:alive?)
      expect(leaked).to be_empty, "leaked #{leaked.size} of #{spawned.size} connect_stream threads"
    end
  end

  # The original leak needed the old thread to be busy somewhere other than IO.select
  # when close + start happened. process_data is the realistic case: it performs
  # synchronous splitChanges/segmentChanges fetches inside the reader thread.
  it 'does not leave a superseded thread running while it is busy in process_data' do
    mock_server do |server|
      serve_stream(server)

      in_process_data = Queue.new
      sse_client.define_singleton_method(:process_data) do |_partial_data|
        in_process_data.push(Thread.current)
        sleep 2
      end

      expect(sse_client.start(server.base_uri)).to eq(true)
      thread_a = config.threads[:connect_stream]

      in_process_data.pop # thread A is now parked inside process_data
      expect(thread_a.alive?).to eq(true)

      sse_client.close
      expect(sse_client.start(server.base_uri)).to eq(true)
      thread_b = config.threads[:connect_stream]
      expect(thread_b).not_to eq(thread_a)

      sleep 4 # well past thread A's 2s process_data

      expect(thread_a.alive?).to eq(false), 'superseded thread A is still running on thread B\'s socket'
      expect(thread_b.alive?).to eq(true)

      sse_client.close
    end
  end

  it 'keeps the total thread count bounded across a reconnect storm' do
    mock_server do |server|
      serve_stream(server)

      baseline = Thread.list.size
      60.times do
        sse_client.start(server.base_uri)
        sse_client.close
      end
      sleep 2

      expect(Thread.list.size).to be < baseline + 10,
                                  "thread count grew from #{baseline} to #{Thread.list.size} over 60 reconnects"
    end
  end
end
