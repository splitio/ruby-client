# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Events::EventsManager do
  subject { SplitIoClient::Engine::Events::EventsManager }
    let(:metadata) { nil }
    let(:sdk_ready) { false }
    let(:sdk_update) { false }
    let(:first_event) { nil }
    

    it 'test_firing_events' do
      config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
      manager = subject.new(SplitIoClient::Engine::Events::EventsManagerConfig.new, 
                            SplitIoClient::Engine::Events::EventsDelivery.new(config), 
                            config)
      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_READY, method(:ready_call_back))
      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE, method(:update_call_back))
      meta = SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE, ["feature1"])

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY, nil)
      sleep 0.5
      expect(@metadata).to be(nil)
      expect(@sdk_ready).to be(true)
      expect(@sdk_update).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(meta)
      expect(@sdk_update).to be(true)
      expect(@sdk_ready).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAG_KILLED_NOTIFICATION, meta)
      sleep 0.5
      expect(@metadata).to eq(meta)
      expect(@sdk_update).to be(true)
      expect(@sdk_ready).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::SEGMENTS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(meta)
      expect(@sdk_update).to be(true)
      expect(@sdk_ready).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::RB_SEGMENTS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(meta)
      expect(@sdk_update).to be(true)
      expect(@sdk_ready).to be(false)
    end

    it 'events fire only after register' do
      config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
      manager = subject.new(SplitIoClient::Engine::Events::EventsManagerConfig.new, 
                            SplitIoClient::Engine::Events::EventsDelivery.new(config), 
                            config)
      meta = SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE, ["feature1"])

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY, nil)
      sleep 0.5
      expect(@metadata).to be(nil)
      expect(@sdk_ready).to be(false)
      expect(@sdk_update).to be(false)

      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_READY, method(:ready_call_back))
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY, nil)
      sleep 0.5
      expect(@metadata).to be(nil)
      expect(@sdk_ready).to be(true)
      expect(@sdk_update).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(nil)
      expect(@sdk_update).to be(false)
      expect(@sdk_ready).to be(false)

      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE, method(:update_call_back))
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(meta)
      expect(@sdk_update).to be(true)
      expect(@sdk_ready).to be(false)
    end

    it 'update fires only after ready events' do
      config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
      manager = subject.new(SplitIoClient::Engine::Events::EventsManagerConfig.new, 
                            SplitIoClient::Engine::Events::EventsDelivery.new(config), 
                            config)
      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_READY, method(:ready_call_back))
      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE, method(:update_call_back))
      meta = SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE, ["feature1"])

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(nil)
      expect(@sdk_update).to be(false)
      expect(@sdk_ready).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY, nil)
      sleep 0.5
      expect(@metadata).to be(nil)
      expect(@sdk_ready).to be(true)
      expect(@sdk_update).to be(false)

      reset_flags
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, meta)
      sleep 0.5
      expect(@metadata).to eq(meta)
      expect(@sdk_update).to be(true)
      expect(@sdk_ready).to be(false)
    end

    it 'event ordered correctly' do
      config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
      manager = subject.new(SplitIoClient::Engine::Events::EventsManagerConfig.new, 
                            SplitIoClient::Engine::Events::EventsDelivery.new(config), 
                            config)
      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_READY, method(:ready_call_back))
      manager.register(SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE, method(:update_call_back))
      meta = SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE, ["feature1"])

      reset_flags
      @first_event = nil
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY, nil)
      manager.notify_internal_event(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, meta)
      sleep 0.5
      expect(@first_event).to be("ready")
    end

    def ready_call_back(metadata)
      @sdk_ready = true
      @metadata = metadata
      @first_event = "ready" if @first_event.nil?
    end

    def update_call_back(metadata)
      @sdk_update = true
      @metadata = metadata
      @first_event = "update" if @first_event.nil?
    end

    def reset_flags
      @sdk_ready = false
      @sdk_update = false
      @metadata = nil
    end
end
