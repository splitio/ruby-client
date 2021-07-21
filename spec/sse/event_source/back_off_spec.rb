# frozen_string_literal: true

require 'spec_helper'
require 'http_server_mock'

describe SplitIoClient::Engine::BackOff do
  subject { SplitIoClient::Engine::BackOff }

  let(:log) { StringIO.new }

  it 'get intervals and reset attemps' do
    back_off = subject.new(1, 0, 5)

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
    streaming_reconnect_back_off_base = 5
    back_off = subject.new(streaming_reconnect_back_off_base, 0, 30)

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

  it 'with max' do
    streaming_reconnect_back_off_base = 5
    back_off = subject.new(streaming_reconnect_back_off_base, 0, 30)

    firts_interval = back_off.interval
    expect(firts_interval).to eq(0)

    second_interval = back_off.interval
    expect(second_interval).to eq(10)

    third_interval = back_off.interval
    expect(third_interval).to eq(20)

    third_interval = back_off.interval
    expect(third_interval).to eq(30)

    third_interval = back_off.interval
    expect(third_interval).to eq(30)

    third_interval = back_off.interval
    expect(third_interval).to eq(30)

    third_interval = back_off.interval
    expect(third_interval).to eq(30)

    back_off.reset
    reset_interval = back_off.interval
    expect(reset_interval).to eq(0)
  end
end
