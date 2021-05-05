# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::RuntimeConsumer do
  subject { SplitIoClient::Telemetry::RuntimeConsumer }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:storage) { SplitIoClient::Telemetry::Storages::Memory.new }
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config, storage) }
  let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config, storage) }

  it 'record and pop tags' do
    result = runtime_consumer.pop_tags
    expect(result.length).to eq(0)

    runtime_producer.add_tag('tag-1')
    runtime_producer.add_tag('tag-2')
    runtime_producer.add_tag('tag-3')
    runtime_producer.add_tag('tag-4')
    runtime_producer.add_tag('tag-5')

    result = runtime_consumer.pop_tags

    expect(result.length).to eq(5)
    expect(result.include?('tag-1')).to be true
    expect(result.include?('tag-2')).to be true
    expect(result.include?('tag-3')).to be true
    expect(result.include?('tag-4')).to be true
    expect(result.include?('tag-5')).to be true

    result = runtime_consumer.pop_tags
    expect(result.length).to eq(0)
  end

  it 'record and get impressions stats' do
    expect(runtime_consumer.impressions_stats('impressions_dropped')).to eq(0)
    expect(runtime_consumer.impressions_stats('impressions_deduped')).to eq(0)
    expect(runtime_consumer.impressions_stats('impressions_queued')).to eq(0)

    runtime_producer.record_impressions_stats('impressions_deduped', 2)
    runtime_producer.record_impressions_stats('impressions_queued', 4)
    runtime_producer.record_impressions_stats('impressions_dropped', 1)
    runtime_producer.record_impressions_stats('impressions_dropped', 6)
    runtime_producer.record_impressions_stats('impressions_queued', 5)

    expect(runtime_consumer.impressions_stats('impressions_dropped')).to eq(7)
    expect(runtime_consumer.impressions_stats('impressions_deduped')).to eq(2)
    expect(runtime_consumer.impressions_stats('impressions_queued')).to eq(9)

    runtime_producer.record_impressions_stats('impressions_deduped', 1)
    runtime_producer.record_impressions_stats('impressions_dropped', 1)
    runtime_producer.record_impressions_stats('impressions_queued', 1)

    expect(runtime_consumer.impressions_stats('impressions_dropped')).to eq(8)
    expect(runtime_consumer.impressions_stats('impressions_deduped')).to eq(3)
    expect(runtime_consumer.impressions_stats('impressions_queued')).to eq(10)
  end

  it 'record and get events stats' do
    expect(runtime_consumer.events_stats('events_dropped')).to eq(0)
    expect(runtime_consumer.events_stats('events_queued')).to eq(0)

    runtime_producer.record_events_stats('events_dropped', 3)
    runtime_producer.record_events_stats('events_dropped', 2)
    runtime_producer.record_events_stats('events_queued', 5)
    runtime_producer.record_events_stats('events_queued', 6)

    expect(runtime_consumer.events_stats('events_dropped')).to eq(5)
    expect(runtime_consumer.events_stats('events_queued')).to eq(11)

    runtime_producer.record_events_stats('events_dropped', 1)
    runtime_producer.record_events_stats('events_queued', 1)

    expect(runtime_consumer.events_stats('events_dropped')).to eq(6)
    expect(runtime_consumer.events_stats('events_queued')).to eq(12)
  end
end
