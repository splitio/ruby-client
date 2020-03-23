# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::SSE::EventSource::BackOff do
  subject { SplitIoClient::SSE::EventSource::BackOff }

  let(:log) { StringIO.new }

  it 'get intervals and reset attemps' do
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(log))
    back_off = subject.new(config)

    firts_interval = back_off.interval
    expect(firts_interval).to eq(0)

    second_interval = back_off.interval
    expect(second_interval).to eq(2)

    third_interval = back_off.interval
    expect(third_interval).to eq(4)

    back_off.reset
    reset_interval = back_off.interval
    expect(reset_interval).to eq(0)
  end

  it 'with custom config' do
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(log), streaming_reconnect_back_off_base: 5)
    back_off = subject.new(config)

    firts_interval = back_off.interval
    expect(firts_interval).to eq(0)

    second_interval = back_off.interval
    expect(second_interval).to eq(10)

    third_interval = back_off.interval
    expect(third_interval).to eq(20)

    back_off.reset
    reset_interval = back_off.interval
    expect(reset_interval).to eq(0)
  end

  it 'setting config less than 1. Minimum allowed is 1.' do
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(log), streaming_reconnect_back_off_base: 0.5)
    back_off = subject.new(config)

    firts_interval = back_off.interval
    expect(firts_interval).to eq(0)

    second_interval = back_off.interval
    expect(second_interval).to eq(2)

    third_interval = back_off.interval
    expect(third_interval).to eq(4)

    back_off.reset
    reset_interval = back_off.interval
    expect(reset_interval).to eq(0)
  end
end
