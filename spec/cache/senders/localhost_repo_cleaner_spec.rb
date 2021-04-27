# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::LocalhostRepoCleaner do
  context '#clear_repositories' do
    let(:config) { SplitIoClient::SplitConfig.new }

    let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:events_repository) { SplitIoClient::Cache::Repositories::EventsRepository.new(config, 'localhost') }
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:impressions_manager) do
      SplitIoClient::Engine::Common::ImpressionManager.new(config, impressions_repository, impression_counter)
    end

    let(:cleaner) { described_class.new(impressions_repository, events_repository, config) }

    before do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_return(status: 200, body: 'ok')
    end

    it 'clears repositories when called' do
      treatment_data = { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 }
      params = { attributes: {}, time: nil }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key',
                                                          'foo1',
                                                          'foo1',
                                                          treatment_data,
                                                          params)

      impressions_manager.track(impressions)

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

      cleaner.send(:clear_repositories)

      expect(impressions_repository.empty?).to be true
      expect(empty_events_repository?).to be true
    end

    def empty_events_repository?
      events_repository.instance_variable_get(:@repository).instance_variable_get(:@adapter).empty?
    end
  end
end
