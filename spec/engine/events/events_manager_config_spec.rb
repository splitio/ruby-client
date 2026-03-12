# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Events::EventsManagerConfig do
  subject { SplitIoClient::Engine::Events::EventsManagerConfig }

    it 'test_build_instance' do
        config = subject.new

        expect(config.require_all[SplitIoClient::Engine::Models::SdkEvent::SDK_READY].length).to eq(1)
        expect(config.require_all[SplitIoClient::Engine::Models::SdkEvent::SDK_READY].include?(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY)).to eq(true)

        expect(config.prerequisites[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].include?(SplitIoClient::Engine::Models::SdkEvent::SDK_READY)).to eq(true)
                                                          
        expect(config.execution_limits[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE]).to eq(-1)
        expect(config.execution_limits[SplitIoClient::Engine::Models::SdkEvent::SDK_READY]).to eq(1)

        expect(config.require_any[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].length).to eq(4)
        expect(config.require_any[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].include?(SplitIoClient::Engine::Models::SdkInternalEvent::FLAG_KILLED_NOTIFICATION)).to be(true)
        expect(config.require_any[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].include?(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED)).to be(true)
        expect(config.require_any[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].include?(SplitIoClient::Engine::Models::SdkInternalEvent::RB_SEGMENTS_UPDATED)).to be(true)
        expect(config.require_any[SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].include?(SplitIoClient::Engine::Models::SdkInternalEvent::SEGMENTS_UPDATED)).to be(true)

        order = 0
        expect(config.evaluation_order.length).to eq(2)
        config.evaluation_order.each do |sdk_event|
            order += 1            
            if order == 1
                expect(sdk_event).to eq(SplitIoClient::Engine::Models::SdkEvent::SDK_READY)
            end
            if order == 2
                expect(sdk_event).to eq(SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE)
            end
        end
    end
end
