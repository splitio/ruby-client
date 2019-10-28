# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Repositories::EventsRepository do
  context 'memory adapter' do
    let(:events_queue_size) { 1 }
    let(:config) do
      SplitIoClient::SplitConfig.new(
        events_adapter: adapter,
        events_queue_size: events_queue_size
      )
    end

    let(:adapter) do
      SplitIoClient::Cache::Adapters::MemoryAdapter.new(
        SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(
          events_queue_size
        )
      )
    end

    let(:repository) { described_class.new(config, nil) }

    before do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_return(status: 200, body: 'ok')
    end

    it 'flushes data when it gets to MAX number of events' do
      expect_any_instance_of(described_class)
        .to receive(:post_events)

      config.events_queue_size.times do |index|
        repository.add(index.to_s, 'traffic_type', 'event_type', (Time.now.to_f * 1000).to_i, 'value', nil, 0)
      end
    end

    it 'flushes data when it gets to MAX size of events' do
      expect_any_instance_of(described_class)
        .to receive(:post_events)

      config.events_queue_size.times do |index|
        repository.add(
          index.to_s,
          'traffic_type',
          'event_type',
          (Time.now.to_f * 1000).to_i,
          'value',
          nil,
          SplitIoClient::Cache::Repositories::Events::MemoryRepository::EVENTS_MAX_SIZE_BYTES
        )
      end
    end
  end

  context 'redis adapter' do
    let(:events_queue_size) { 2 }
    let(:config) do
      SplitIoClient::SplitConfig.new(
        cache_adapter: :redis,
        events_queue_size: events_queue_size
      )
    end
    let(:repository) { described_class.new(config, nil) }
    let(:adapter) { config.events_adapter }

    before do
      Redis.new.flushall
    end

    it 'with ip_addresses_enabled set true' do
      config.events_queue_size.times do |index|
        repository.add(index.to_s, 'traffic_type', 'event_type', (Time.now.to_f * 1000).to_i, 'value', nil, 0)
      end

      adapter.get_from_queue('SPLITIO.events', 0).map do |e|
        event = JSON.parse(e, symbolize_names: true)
        
        expect(event[:m][:i]).to eq config.machine_ip
        expect(event[:m][:n]).to eq config.machine_name
      end
    end

    it 'with ip_addresses_enabled set false' do
      config = SplitIoClient::SplitConfig.new(cache_adapter: :redis, events_queue_size: 3, ip_addresses_enabled: false)
      repository = described_class.new(config, nil)
      adapter = config.events_adapter 

      config.events_queue_size.times do |index|
        repository.add(index.to_s, 'traffic_type', 'event_type', (Time.now.to_f * 1000).to_i, 'value', nil, 0)
      end

      adapter.get_from_queue('SPLITIO.events', 0).map do |e|
        event = JSON.parse(e, symbolize_names: true)
        
        expect(event[:m][:i]).to eq 'NA'
        expect(event[:m][:n]).to eq 'NA'
      end
    end
  end
end
