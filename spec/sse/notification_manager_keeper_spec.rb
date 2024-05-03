# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SSE::NotificationManagerKeeper do
  subject { SplitIoClient::SSE::NotificationManagerKeeper }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:push_status_queue) { Queue.new }
  let(:noti_manager_keeper) { subject.new(config, telemetry_runtime_producer, push_status_queue) }

  context 'CONTROL EVENT' do
    it 'STREAMING_PAUSED' do
      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_PAUSED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)
    end

    it 'STREAMING_RESUMED with publishers enabled' do
      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_RESUMED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_READY)
    end

    it 'STREAMING_RESUMED without publishers enabled' do
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)

      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_RESUMED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)
    end

    it 'STREAMING_DISABLED' do
      data = { 'type' => 'CONTROL', 'controlType' => 'STREAMING_DISABLED' }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_OFF)
    end
  end

  context 'OCCUPANCY EVENT' do
    it 'first time without publishers available' do
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)
    end

    it 'first time with publishers available' do
      data = { 'metrics' => { 'publishers' => 2 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)
    end

    it 'handle many events' do
      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)

      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)

      data = { 'metrics' => { 'publishers' => 1 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-clienrubot-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_READY)

      data = { 'metrics' => { 'publishers' => 2 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)

      data = { 'metrics' => { 'publishers' => 5 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_READY)

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)

      data = { 'metrics' => { 'publishers' => 1 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_READY)

      data = { 'metrics' => { 'publishers' => 2 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

      data = { 'metrics' => { 'publishers' => 3 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect(push_status_queue.pop(true)).to eq(SplitIoClient::Constants::PUSH_SUBSYSTEM_DOWN)

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_sec')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)

      data = { 'metrics' => { 'publishers' => 0 } }
      event = SplitIoClient::SSE::EventSource::StreamData.new('message', 'test-client-id', data, 'control_pri')
      noti_manager_keeper.handle_incoming_occupancy_event(event)
      expect { push_status_queue.pop(true) }.to raise_error(ThreadError)
    end
  end
end
