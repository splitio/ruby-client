# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Events::EventsDelivery do
  subject { SplitIoClient::Engine::Events::EventsDelivery }
    let(:metadata) { nil }

    it 'test calling handler' do
        config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))        
        delivery = subject.new(config)

        delivery.deliver(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED,
                         SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE),
                         method(:call_back)
                        )
        sleep 0.5
        expect(@metadata.type).to be(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE)
    end

    it 'test exception when calling handler' do
        log = StringIO.new
        config = SplitIoClient::SplitConfig.new(logger: Logger.new(log))        
        delivery = subject.new(config)

        delivery.deliver(SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED,
                         SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE),
                         method(:call_with_exception)
                        )
        sleep 0.5
        expect(log.string).to include 'Exception when calling handler for Sdk Event' \
    end

    def call_back(metadata)
        @metadata = metadata
    end

    def call_with_exception(metadata)
        raise StandardError("call exception")
    end
end
