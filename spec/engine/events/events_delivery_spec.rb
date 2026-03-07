# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::Events::EventsDelivery do
  subject { SplitIoClient::Engine::Events::EventsDelivery }

  it 'calls handler successfully' do
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
    delivery = subject.new(config)

    delivery.deliver(
      SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED,
      SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE),
      method(:call_back)
    )
    sleep 0.5
    expect(@metadata.type).to be(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE)
  end

  it 'handles exception when calling handler' do
    log = StringIO.new
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(log))
    delivery = subject.new(config)

    delivery.deliver(
      SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED,
      SplitIoClient::Engine::Models::EventsMetadata.new(SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE),
      method(:call_with_exception)
    )
    sleep 0.5
    expect(log.string).to include('Exception when calling handler for Sdk Event')
  end

  it 'logs the sdk event name when handler raises exception' do
    log = StringIO.new
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(log))
    delivery = subject.new(config)

    delivery.deliver(
      SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY,
      nil,
      method(:call_with_exception)
    )
    sleep 0.5
    expect(log.string).to include('Exception when calling handler for Sdk Event')
    expect(log.string).to include(SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY.to_s)
  end

  it 'calls handler with correct metadata' do
    config = SplitIoClient::SplitConfig.new(logger: Logger.new(StringIO.new))
    delivery = subject.new(config)
    metadata = SplitIoClient::Engine::Models::EventsMetadata.new(
      SplitIoClient::Engine::Models::SdkEventType::FLAG_UPDATE,
      ['feature1', 'feature2']
    )

    delivery.deliver(
      SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED,
      metadata,
      method(:call_back)
    )
    sleep 0.5
    expect(@metadata).to eq(metadata)
  end

  def call_back(metadata)
    @metadata = metadata
  end

  def call_with_exception(_metadata)
    raise StandardError, 'call exception'
  end
end
