# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Events::EventsTask do
  subject { SplitIoClient::Engine::Events::EventsTask }
    let(:internal_event) { nil }
    let(:metadata) { nil }

    it 'test_task_running' do
        queue = Queue.new
        config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
        task = subject.new(method(:call_back), queue, config)
        task.start
        expect(task.running).to be(true)

        queue.push(SplitIoClient::Engine::Models::SdkInternalEventNotification.new(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE)))
        sleep 0.5
        expect(@internal_event).to be(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED)
        expect(@metadata.type).to be(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE)

        @internal_event = nil
        @metadata = nil
        queue.push(SplitIoClient::Engine::Models::SdkInternalEventNotification.new(SplitIoClient::Engine::Models::SdkInternalEvent::RB_SEGMENTS_UPDATED, SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::SEGMENTS_UPDATE)))
        sleep 0.5
        expect(@internal_event).to be(SplitIoClient::Engine::Models::SdkInternalEvent::RB_SEGMENTS_UPDATED)
        expect(@metadata.type).to be(SplitIoClient::Engine::Models::SdkEventType::SEGMENTS_UPDATE)

        task.stop
        sleep 0.2
        expect(task.running).to be(false)

    end

    def call_back(internal_event, metadata)
        @internal_event = internal_event
        @metadata = metadata
    end

end
