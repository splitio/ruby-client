# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::LocalhostRepoCleaner do
  context '#clear_repositories' do
    let(:config) { SplitIoClient::SplitConfig.new }

    let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:metrics_repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(config) }
    let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, 'localhost') }

    let(:cleaner) { described_class.new(impressions_repository, metrics_repository, events_repository, config) }

    before do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_return(status: 200, body: 'ok')
    end

    it 'clears repositories when called' do
      impressions_repository.add(
        'matching_key',
        'foo1',
        'foo1',
        { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 },
        1_478_113_516_002
      )

      metrics_repository.add_latency('foo', 0, SplitIoClient::BinarySearchLatencyTracker.new)

      events_repository.add(
        'event',
        'traffic_type',
        'event_type',
        (Time.now.to_f * 1000).to_i,
        'value',
        nil,
        1
      )

      expect(impressions_repository.empty?).to be false
      expect(empty_events_repository?).to be false
      expect(empty_metrics_repository?).to be false

      cleaner.send(:clear_repositories)

      expect(impressions_repository.empty?).to be true
      expect(empty_events_repository?).to be true
      expect(empty_metrics_repository?).to be true
    end

    def empty_events_repository?
      events_repository.instance_variable_get(:@repository).instance_variable_get(:@adapter).empty?
    end

    def empty_metrics_repository?
      metrics_repository.instance_variable_get(:@repository).instance_variable_get(:@latencies).empty?
    end
  end
end
