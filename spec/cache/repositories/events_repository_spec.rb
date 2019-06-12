# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Repositories::EventsRepository do
  context 'memory adapter' do
    let(:adapter) do
      SplitIoClient::Cache::Adapters::MemoryAdapter.new(
        SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(
          SplitIoClient.configuration.events_queue_size
        )
      )
    end

    let(:repository) { described_class.new(adapter, nil) }

    before do
      SplitIoClient.configuration.events_queue_size = 1

      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_return(status: 200, body: 'ok')
    end

    it 'flushes data when it gets to MAX number of events' do
      expect_any_instance_of(described_class)
        .to receive(:post_events)

      SplitIoClient.configuration.events_queue_size.times do |index|
        repository.add(index.to_s, 'traffic_type', 'event_type', (Time.now.to_f * 1000).to_i, 'value', nil, 0)
      end
    end

    it 'flushes data when it gets to MAX size of events' do
      expect_any_instance_of(described_class)
        .to receive(:post_events)

      SplitIoClient.configuration.events_queue_size.times do |index|
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
end
