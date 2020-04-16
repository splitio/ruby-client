# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SSE::NotificationManagerKeeper do
  subject { SplitIoClient::SSE::NotificationManagerKeeper }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }

  context 'first time' do
    it 'without publishers available' do
      result = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |publishers_available| result = publishers_available }
      end
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(false)
    end

    it 'with publishers available' do
      result = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |publishers_available| result = publishers_available }
      end
      data = { 'metrics' => { 'publishers' => 2 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(nil)
    end
  end

  it 'handle many events' do
    result = nil

    noti_manager_keeper = subject.new(config) do |manager|
      manager.on_occupancy { |publishers_available| result = publishers_available }
    end
    data = { 'metrics' => { 'publishers' => 0 } }
    event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
    noti_manager_keeper.handle_incoming_occupancy_event(event)
    expect(result).to eq(false)

    result = nil
    data = { 'metrics' => { 'publishers' => 1 } }
    event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-clienrubot-id', data, 'control_pri')
    noti_manager_keeper.handle_incoming_occupancy_event(event)
    expect(result).to eq(true)

    result = nil
    data = { 'metrics' => { 'publishers' => 2 } }
    event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
    noti_manager_keeper.handle_incoming_occupancy_event(event)
    expect(result).to eq(nil)

    result = nil
    data = { 'metrics' => { 'publishers' => 0 } }
    event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
    noti_manager_keeper.handle_incoming_occupancy_event(event)
    expect(result).to eq(false)

    result = nil
    data = { 'metrics' => { 'publishers' => 5 } }
    event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
    noti_manager_keeper.handle_incoming_occupancy_event(event)
    expect(result).to eq(true)
  end
end
