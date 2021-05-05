# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::InitConsumer do
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:storage) { SplitIoClient::Telemetry::Storages::Memory.new }
  let(:init_producer) { SplitIoClient::Telemetry::InitProducer.new(config, storage) }
  let(:init_consumer) { SplitIoClient::Telemetry::InitConsumer.new(config, storage) }

  it 'record and get bur timeouts' do
    result = init_consumer.bur_timeouts

    expect(result).to eq(0)

    init_producer.record_bur_timeout
    init_producer.record_bur_timeout
    init_producer.record_bur_timeout

    result = init_consumer.bur_timeouts

    expect(result).to eq(3)

    init_producer.record_bur_timeout

    result = init_consumer.bur_timeouts

    expect(result).to eq(4)
  end

  it 'record and get non ready usages' do
    result = init_consumer.non_ready_usages

    expect(result).to eq(0)

    init_producer.record_non_ready_usages
    init_producer.record_non_ready_usages
    init_producer.record_non_ready_usages
    init_producer.record_non_ready_usages

    result = init_consumer.non_ready_usages

    expect(result).to eq(4)

    init_producer.record_non_ready_usages

    result = init_consumer.non_ready_usages

    expect(result).to eq(5)
  end
end
