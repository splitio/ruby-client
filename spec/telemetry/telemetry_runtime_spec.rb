# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::RuntimeConsumer do
  subject { SplitIoClient::Telemetry::RuntimeConsumer }

  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }

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

  it 'record and get last synchronizations' do
    result = runtime_consumer.last_synchronizations
    expect(result.sp).to be(0)
    expect(result.se).to be(0)
    expect(result.im).to be(0)
    expect(result.ic).to be(0)
    expect(result.ev).to be(0)
    expect(result.te).to be(0)
    expect(result.to).to be(0)

    runtime_producer.record_successful_sync('split_sync', 111_112)
    runtime_producer.record_successful_sync('impressions_sync', 222_333)
    runtime_producer.record_successful_sync('event_sync', 444_555)

    result = runtime_consumer.last_synchronizations
    expect(result.sp).to be(111_112)
    expect(result.se).to be(0)
    expect(result.im).to be(222_333)
    expect(result.ic).to be(0)
    expect(result.ev).to be(444_555)
    expect(result.te).to be(0)
    expect(result.to).to be(0)

    runtime_producer.record_successful_sync('split_sync', 999_999)

    result = runtime_consumer.last_synchronizations
    expect(result.sp).to be(999_999)
    expect(result.se).to be(0)
    expect(result.im).to be(222_333)
    expect(result.ic).to be(0)
    expect(result.ev).to be(444_555)
    expect(result.te).to be(0)
    expect(result.to).to be(0)
  end

  it 'record and pop sync_errors' do
    result = runtime_consumer.pop_http_errors
    expect(result.sp.empty?).to be true
    expect(result.se.empty?).to be true
    expect(result.im.empty?).to be true
    expect(result.ic.empty?).to be true
    expect(result.ev.empty?).to be true
    expect(result.te.empty?).to be true
    expect(result.to.empty?).to be true

    runtime_producer.record_sync_error('split_sync', 500)
    runtime_producer.record_sync_error('split_sync', 500)
    runtime_producer.record_sync_error('split_sync', 500)
    runtime_producer.record_sync_error('split_sync', 500)
    runtime_producer.record_sync_error('split_sync', 400)
    runtime_producer.record_sync_error('split_sync', 400)

    runtime_producer.record_sync_error('segment_sync', 500)
    runtime_producer.record_sync_error('segment_sync', 500)

    result = runtime_consumer.pop_http_errors
    expect(result.sp.length).to be(2)
    expect(result.sp[500]).to be(4)
    expect(result.sp[400]).to be(2)
    expect(result.se.length).to be(1)
    expect(result.se[500]).to be(2)
    expect(result.im.empty?).to be true
    expect(result.ic.empty?).to be true
    expect(result.ev.empty?).to be true
    expect(result.te.empty?).to be true
    expect(result.to.empty?).to be true

    result = runtime_consumer.pop_http_errors
    expect(result.sp.empty?).to be true
    expect(result.se.empty?).to be true
    expect(result.im.empty?).to be true
    expect(result.ic.empty?).to be true
    expect(result.ev.empty?).to be true
    expect(result.te.empty?).to be true
    expect(result.to.empty?).to be true
  end

  it 'record and pop sync_latencies' do
    result = runtime_consumer.pop_http_latencies
    expect(result.sp.length).to be(23)
    expect(result.se.length).to be(23)
    expect(result.im.length).to be(23)
    expect(result.ic.length).to be(23)
    expect(result.ev.length).to be(23)
    expect(result.te.length).to be(23)
    expect(result.to.length).to be(23)

    runtime_producer.record_sync_latency('split_sync', 1)
    runtime_producer.record_sync_latency('split_sync', 2)
    runtime_producer.record_sync_latency('split_sync', 3)
    runtime_producer.record_sync_latency('split_sync', 0)
    runtime_producer.record_sync_latency('split_sync', 5)
    runtime_producer.record_sync_latency('split_sync', 2)

    runtime_producer.record_sync_latency('segment_sync', 2)
    runtime_producer.record_sync_latency('segment_sync', 2)
    runtime_producer.record_sync_latency('segment_sync', 2)

    runtime_producer.record_sync_latency('telemetry_sync', 3)
    runtime_producer.record_sync_latency('telemetry_sync', 3)

    result = runtime_consumer.pop_http_latencies
    expect(result.sp[0]).to be(1)
    expect(result.sp[1]).to be(1)
    expect(result.sp[2]).to be(2)
    expect(result.sp[3]).to be(1)
    expect(result.sp[5]).to be(1)
    expect(result.se[2]).to be(3)
    expect(result.te[3]).to be(2)

    result = runtime_consumer.pop_http_latencies
    expect(result.sp.length).to be(23)
    expect(result.se.length).to be(23)
    expect(result.im.length).to be(23)
    expect(result.ic.length).to be(23)
    expect(result.ev.length).to be(23)
    expect(result.te.length).to be(23)
    expect(result.to.length).to be(23)
  end

  it 'record and pop auth_rejections' do
    expect(runtime_consumer.pop_auth_rejections).to be(0)

    runtime_producer.record_auth_rejections
    runtime_producer.record_auth_rejections
    runtime_producer.record_auth_rejections
    runtime_producer.record_auth_rejections

    expect(runtime_consumer.pop_auth_rejections).to be(4)
    expect(runtime_consumer.pop_auth_rejections).to be(0)
  end

  it 'record and pop token_refreshes' do
    expect(runtime_consumer.pop_token_refreshes).to be(0)

    runtime_producer.record_token_refreshes
    runtime_producer.record_token_refreshes
    runtime_producer.record_token_refreshes
    runtime_producer.record_token_refreshes
    runtime_producer.record_token_refreshes
    runtime_producer.record_token_refreshes

    expect(runtime_consumer.pop_token_refreshes).to be(6)
    expect(runtime_consumer.pop_token_refreshes).to be(0)
  end

  it 'record and pop streaming_events' do
    expect(runtime_consumer.pop_streaming_events.length).to be(0)

    runtime_producer.record_streaming_event('type-1', 'data-1', 213_123)
    runtime_producer.record_streaming_event('type-2', 'data-2', 213_123)
    runtime_producer.record_streaming_event('type-3', 'data-3', 213_123)
    runtime_producer.record_streaming_event('type-4', 'data-4', 213_123)

    result = runtime_consumer.pop_streaming_events
    expect(result.length).to be(4)
    expect(result[0][:e]).to be('type-1')
    expect(result[0][:d]).to be('data-1')
    expect(result[0][:t]).to be(213_123)

    expect(result[1][:e]).to be('type-2')
    expect(result[1][:d]).to be('data-2')
    expect(result[1][:t]).to be(213_123)

    expect(result[2][:e]).to be('type-3')
    expect(result[2][:d]).to be('data-3')
    expect(result[2][:t]).to be(213_123)

    expect(result[3][:e]).to be('type-4')
    expect(result[3][:d]).to be('data-4')
    expect(result[3][:t]).to be(213_123)

    30.times do
      runtime_producer.record_streaming_event('type-n', 'data-n', 213_123)
    end

    expect(runtime_consumer.pop_streaming_events.length).to be(19)
  end

  it 'record and get session_length' do
    expect(runtime_consumer.session_length).to be(0)

    runtime_producer.record_session_length(222_555)
    expect(runtime_consumer.session_length).to be(222_555)

    runtime_producer.record_session_length(888_555)
    expect(runtime_consumer.session_length).to be(888_555)
  end
end
