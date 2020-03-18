# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::EventSource::Client do
  subject { SplitIoClient::SSE::EventSource::Client }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:event_split_update) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 5564531221, \\\"defaultTreatment\\\" : \\\"off\\\", \\\"splitName\\\" : \\\"split-test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": 5564531221, \\\"segmentName\\\" : \\\"segment-test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_control) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"data\":\"{\\\"type\\\" : \\\"CONTROL\\\", \\\"controlType\\\" : \\\"control-type-example\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_invalid_format) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"mauroc\",\"content\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }

  it 'receive split update event' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_split_update, keep_open: false)
      end

      event_queue = Queue.new
      connected_event = false
      disconnect_event = false
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event { |event| event_queue << event }
        client.on_connected { connected_event = true }
        client.on_disconnect { disconnect_event = true }
      end

      event_result = event_queue.pop
      expect(event_result.data['type']).to eq(SplitIoClient::SSE::EventSource::EventTypes::SPLIT_UPDATE)
      expect(event_result.data['changeNumber']).to eq(5_564_531_221)
      expect(event_result.client_id).to eq('emptyClientId')
      expect(event_result.event_type).to eq('message')
      expect(sse_client.connected?).to eq(true)
      expect(connected_event).to eq(true)
      expect(disconnect_event).to eq(false)

      sse_client.close

      expect(sse_client.connected?).to eq(false)
      expect(disconnect_event).to eq(true)
    end
  end

  it 'receive split kill event' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_split_kill, keep_open: false)
      end

      event_queue = Queue.new
      connected_event = false
      disconnect_event = false
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event { |event| event_queue << event }
        client.on_connected { connected_event = true }
        client.on_disconnect { disconnect_event = true }
      end

      event_result = event_queue.pop
      expect(event_result.data['type']).to eq(SplitIoClient::SSE::EventSource::EventTypes::SPLIT_KILL)
      expect(event_result.data['changeNumber']).to eq(5_564_531_221)
      expect(event_result.data['defaultTreatment']).to eq('off')
      expect(event_result.data['splitName']).to eq('split-test')
      expect(event_result.client_id).to eq('emptyClientId')
      expect(event_result.event_type).to eq('message')
      expect(sse_client.connected?).to eq(true)
      expect(connected_event).to eq(true)
      expect(disconnect_event).to eq(false)

      sse_client.close

      expect(sse_client.connected?).to eq(false)
      expect(disconnect_event).to eq(true)
    end
  end

  it 'receive segment update event' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_segment_update, keep_open: false)
      end

      event_queue = Queue.new
      connected_event = false
      disconnect_event = false
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event { |event| event_queue << event }
        client.on_connected { connected_event = true }
        client.on_disconnect { disconnect_event = true }
      end

      event_result = event_queue.pop
      expect(event_result.data['type']).to eq(SplitIoClient::SSE::EventSource::EventTypes::SEGMENT_UPDATE)
      expect(event_result.data['changeNumber']).to eq(5_564_531_221)
      expect(event_result.data['segmentName']).to eq('segment-test')
      expect(event_result.client_id).to eq('emptyClientId')
      expect(event_result.event_type).to eq('message')
      expect(sse_client.connected?).to eq(true)
      expect(connected_event).to eq(true)
      expect(disconnect_event).to eq(false)

      sse_client.close

      expect(sse_client.connected?).to eq(false)
      expect(disconnect_event).to eq(true)
    end
  end

  it 'receive control event' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_control, keep_open: false)
      end

      event_queue = Queue.new
      connected_event = false
      disconnect_event = false
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event { |event| event_queue << event }
        client.on_connected { connected_event = true }
        client.on_disconnect { disconnect_event = true }
      end

      event_result = event_queue.pop
      expect(event_result.data['type']).to eq(SplitIoClient::SSE::EventSource::EventTypes::CONTROL)
      expect(event_result.data['controlType']).to eq('control-type-example')
      expect(event_result.client_id).to eq('emptyClientId')
      expect(event_result.event_type).to eq('message')
      expect(sse_client.connected?).to eq(true)
      expect(connected_event).to eq(true)
      expect(disconnect_event).to eq(false)

      sse_client.close

      expect(sse_client.connected?).to eq(false)
      expect(disconnect_event).to eq(true)
    end
  end

  it 'receive invalid format' do
    mock_server do |server|
      server.setup_response('/') do |_, res|
        send_stream_content(res, event_invalid_format, keep_open: false)
      end

      event_queue = Queue.new
      connected_event = false
      disconnect_event = false
      sse_client = subject.new(server.base_uri, config) do |client|
        client.on_event { |event| event_queue << event }
        client.on_connected { connected_event = true }
        client.on_disconnect { disconnect_event = true }
      end

      sleep 0.5
      expect(event_queue.empty?).to be_truthy
      expect(sse_client.connected?).to eq(true)
      expect(connected_event).to eq(true)
      expect(disconnect_event).to eq(false)

      sse_client.close

      expect(sse_client.connected?).to eq(false)
      expect(disconnect_event).to eq(true)
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
