# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SSE::EventSource::EventParser do
  subject { SplitIoClient::SSE::EventSource::EventParser }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }

  let(:event_split_update_ws) { "fb\r\nid:123\nevent:message\ndata:{\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_update) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_split_kill) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SPLIT_KILL\\\",\\\"changeNumber\\\": 5564531221, \\\"defaultTreatment\\\" : \\\"off\\\", \\\"splitName\\\" : \\\"split-test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_segment_update) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"data\":\"{\\\"type\\\" : \\\"SEGMENT_UPDATE\\\",\\\"changeNumber\\\": 5564531221, \\\"segmentName\\\" : \\\"segment-test\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_control) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"control_pri\",\"data\":\"{\\\"type\\\" : \\\"CONTROL\\\", \\\"controlType\\\" : \\\"STREAMING_PAUSED\\\"}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_invalid_format) { "fb\r\nid: 123\nevent: message\ndata: {\"id\":\"1\",\"clientId\":\"emptyClientId\",\"connectionId\":\"1\",\"timestamp\":1582045421733,\"channel\":\"channel-test\",\"content\":\"{\\\"type\\\" : \\\"SPLIT_UPDATE\\\",\\\"changeNumber\\\": 5564531221}\",\"name\":\"asdasd\"}\n\n\r\n" }
  let(:event_occupancy) { "d4\r\nevent: message\ndata: {\"id\":\"123\",\"timestamp\":1586803930362,\"encoding\":\"json\",\"channel\":\"[?occupancy=metrics.publishers]control_pri\",\"data\":\"{\\\"metrics\\\":{\\\"publishers\\\":2}}\",\"name\":\"[meta]occupancy\"}\n\n\r\n" }
  let(:event_error) { "d4\r\nevent: error\ndata: {\"message\":\"Token expired\",\"code\":40142,\"statusCode\":401,\"href\":\"https://help.ably.io/error/40142\"}" }

  it 'split update event' do
    parser = subject.new(config)

    event = parser.parse(event_split_update)[0]
    expect(event.event_type).to eq('message')
    expect(event.data['type']).to eq('SPLIT_UPDATE')
    expect(event.data['changeNumber']).to eq(5_564_531_221)
    expect(event.channel).to eq('channel-test')
  end

  it 'split update event - fixing event parser' do
    parser = subject.new(config)

    event = parser.parse(event_split_update_ws)[0]
    expect(event.event_type).to eq('message')
    expect(event.data['type']).to eq('SPLIT_UPDATE')
    expect(event.data['changeNumber']).to eq(5_564_531_221)
    expect(event.channel).to eq('channel-test')
  end

  it 'split kill event' do
    parser = subject.new(config)

    event = parser.parse(event_split_kill)[0]
    expect(event.event_type).to eq('message')
    expect(event.data['type']).to eq('SPLIT_KILL')
    expect(event.data['changeNumber']).to eq(5_564_531_221)
    expect(event.data['defaultTreatment']).to eq('off')
    expect(event.data['splitName']).to eq('split-test')
    expect(event.channel).to eq('channel-test')
  end

  it 'segment update event' do
    parser = subject.new(config)

    event = parser.parse(event_segment_update)[0]
    expect(event.event_type).to eq('message')
    expect(event.data['type']).to eq('SEGMENT_UPDATE')
    expect(event.data['changeNumber']).to eq(5_564_531_221)
    expect(event.data['segmentName']).to eq('segment-test')
    expect(event.channel).to eq('channel-test')
  end

  it 'control event' do
    parser = subject.new(config)

    event = parser.parse(event_control)[0]
    expect(event.event_type).to eq('message')
    expect(event.data['type']).to eq('CONTROL')
    expect(event.data['controlType']).to eq('STREAMING_PAUSED')
    expect(event.channel).to eq('control_pri')
  end

  it 'occupancy event' do
    parser = subject.new(config)

    event = parser.parse(event_occupancy)[0]
    expect(event.event_type).to eq('message')
    expect(event.data['metrics']['publishers']).to eq(2)
    expect(event.channel).to eq('control_pri')
  end

  it 'invalid format' do
    parser = subject.new(config)

    events = parser.parse(event_invalid_format)
    expect(events).to match_array([])
  end
end
