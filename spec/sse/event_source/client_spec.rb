# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SSE::EventSource::Client do
  subject { SSE::EventSource::Client }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:event_message) do
    <<-ET
    b0
    id: 1
    event: message
    data: {\"id\":\"123\",\"connectionId\":\"1\",\"channel\":\"channel-test\",\"data\":\"data-test\",\"name\":\"name-test\"}
    ET
  end
  let(:event_control) do
    <<-ET
    "b0\
    id: 2
    event: control
    data: {\"id\":\"1243\",\"connectionId\":\"1\",\"channel\":\"channel-test\",\"data\":\"data-test\",\"name\":\"name-test\"}
    ET
  end
  let(:event_fail) do
    <<-ET
    b0
    id: 3
    event: fail
    info: {\"id\":\"1243\",\"connectionId\":\"1\",\"data\":\"data-test\"}
    ET
  end

  it 'receive message event' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_message, keep_open: false)
      end

      event_queue = Queue.new
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event do |event|
          event_queue << event
        end
      end

      event_result = event_queue.pop
      expect(event_result.type).to eq('message')
      expect(event_result.name).to eq('name-test')
      expect(event_result.channel).to eq('channel-test')
      expect(event_result.data).to eq('data-test')
      expect(event_result.id).to eq('123')

      sse_client.close
    end
  end

  it 'receive control event' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_control, keep_open: false)
      end

      event_queue = Queue.new
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event do |event|
          event_queue << event
        end
      end

      event_result = event_queue.pop
      expect(event_result.type).to eq('control')
      expect(event_result.name).to eq('name-test')
      expect(event_result.channel).to eq('channel-test')
      expect(event_result.data).to eq('data-test')
      expect(event_result.id).to eq('1243')

      sse_client.close
    end
  end

  it 'receive incorrect event format' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_fail, keep_open: false)
      end

      event_queue = Queue.new
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event do |event|
          event_queue << event
        end
      end

      expect(event_queue.length).to eq(0)

      sse_client.close
    end
  end

  def send_stream_content(res, content, keep_open:)
    res.content_type = 'text/event-stream'
    res.status = 200
    res.chunked = true
    rd, wr = IO.pipe
    wr.write(content)
    res.body = rd
    wr.close unless keep_open
    wr
  end
end
