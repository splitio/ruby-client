# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SSE::NotificationManagerKeeper do
  subject { SplitIoClient::SSE::NotificationManagerKeeper }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }

  context 'CONTROL EVENT' do
    it 'STREAMING_PAUSED' do
      result = nil
      shutdown = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
        manager.on_push_shutdown { shutdown = true }
      end
      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_PAUSED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(false)
      expect(shutdown).to eq(nil)
    end

    it 'STREAMING_RESUMED with publishers enabled' do
      result = nil
      shutdown = nil
      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
        manager.on_push_shutdown { shutdown = true }
      end
      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_RESUMED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(true)
      expect(shutdown).to eq(nil)
    end

    it 'STREAMING_RESUMED without publishers enabled' do
      result = nil
      shutdown = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
        manager.on_push_shutdown { shutdown = true }
      end

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_RESUMED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      result = nil
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(nil)
      expect(shutdown).to eq(nil)
    end

    it 'STREAMING_DISABLED' do
      result = nil
      shutdown = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
        manager.on_push_shutdown { shutdown = true }
      end
      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_DISABLED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(nil)
      expect(shutdown).to eq(true)
    end
  end

  context 'OCCUPANCY EVENT' do
    it 'first time without publishers available' do
      result = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
      end
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(false)
    end

    it 'first time with publishers available' do
      result = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
      end
      data = { 'metrics' => { 'publishers' => 2 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(result).to eq(nil)
    end

    it 'handle many events' do
      result = nil

      noti_manager_keeper = subject.new(config) do |manager|
        manager.on_occupancy { |push_enable| result = push_enable }
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

      result = nil
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(false)

      result = nil
      data = { 'metrics' => { 'publishers' => 1 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(true)

      result = nil
      data = { 'metrics' => { 'publishers' => 2 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(nil)

      result = nil
      data = { 'metrics' => { 'publishers' => 3 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(nil)

      result = nil
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(nil)

      result = nil
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(false)

      result = nil
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(nil)

      result = nil
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(result).to eq(nil)
    end
  end
end
