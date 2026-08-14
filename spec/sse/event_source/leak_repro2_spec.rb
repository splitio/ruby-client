# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

# TEMPORARY evidence spec for FME-18143. Not intended to be merged.
# Hypothesis: if a connect_stream thread is busy in process_data when close()+start()
# happen, it resumes, sees connected? == true (set by the NEW thread) and continues
# reading from the NEW thread's socket -> two threads on one socket, old one never exits.
describe 'FME-18143 connect_stream thread leak via busy process_data' do
  let(:log) { StringIO.new }
  let(:events_queue) { Queue.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), debug_enabled: false) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:api_token) { 'api-token-test' }
  let(:event_parser) { SplitIoClient::SSE::EventSource::EventParser.new(config) }
  let(:push_status_queue) { Queue.new }
  let(:notification_manager_keeper) { SplitIoClient::SSE::NotificationManagerKeeper.new(config, telemetry_runtime_producer, push_status_queue) }

  let(:keepalive) { "c\r\n:keepalive\n\n\r\n" }

  it 'old thread survives and reads the new socket' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        res.content_type = 'text/event-stream'
        res.status = 200
        res.chunked = true
        rd, wr = IO.pipe
        wr.write(keepalive)
        res.body = rd
        Thread.new do
          # keep dribbling data so a live reader always has something to consume
          20.times { sleep 0.5; (wr.write(keepalive) rescue nil) }
          wr.close rescue nil
        end
      end

      sse_client = SplitIoClient::SSE::EventSource::Client.new(
        config, api_token, telemetry_runtime_producer, event_parser,
        notification_manager_keeper, double(process: true), push_status_queue
      )

      # Make process_data slow, simulating the real SDK doing an HTTP splitChanges
      # fetch inside the connect_stream thread.
      in_process_data = Queue.new
      sse_client.define_singleton_method(:process_data) do |_partial|
        in_process_data.push(Thread.current)
        sleep 2
      end

      expect(sse_client.start(server.base_uri)).to eq(true)
      thread_a = config.threads[:connect_stream]

      # wait until thread A is parked inside process_data
      in_process_data.pop
      expect(thread_a.alive?).to eq(true)

      # storm pattern: close + immediate restart while A is busy
      sse_client.close
      expect(sse_client.start(server.base_uri)).to eq(true)
      thread_b = config.threads[:connect_stream]
      expect(thread_b).not_to eq(thread_a)

      sleep 4 # A has long since returned from its 2s process_data

      puts "\n[FME-18143] thread_a alive after restart: #{thread_a.alive?}"
      puts "[FME-18143] thread_b alive: #{thread_b.alive?}"
      puts "[FME-18143] total ruby threads: #{Thread.list.size}"

      expect(thread_a.alive?).to eq(false), 'thread A leaked: it is still running on thread B\'s socket'

      sse_client.close
    end
  end
end
