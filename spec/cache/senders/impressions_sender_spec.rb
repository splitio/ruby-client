# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsSender do
  RSpec.shared_examples 'Impressions Sender' do |cache_adapter|
    let(:config) do
      SplitIoClient::SplitConfig.new(
        cache_adapter: cache_adapter,
        impressions_queue_size: 5
      )
    end
    let(:repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:impression_api) { SplitIoClient::Api::Impressions.new(nil, config, telemetry_runtime_producer) }
    let(:sender) { described_class.new(repository, config, impression_api) }
    let(:formatted_impressions) { SplitIoClient::Cache::Senders::ImpressionsFormatter.new(repository).call(true) }
    let(:treatment1) { { treatment: 'on', label: 'custom_label1', change_number: 123_456 } }
    let(:treatment2) { { treatment: 'off', label: 'custom_label2', change_number: 123_499 } }
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
    let(:unique_keys_tracker) do
      bf = SplitIoClient::Cache::Filter::BloomFilter.new(1_000)
      filter_adapter = SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf)
      api_key = 'ImpressionsSender-key'
      telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, api_key, telemetry_runtime_producer)
      sender_adapter = SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impression_api)

      SplitIoClient::Engine::Impressions::UniqueKeysTracker.new(config,
                                                                filter_adapter,
                                                                sender_adapter,
                                                                Concurrent::Hash.new)
    end
    let(:impressions_manager) do
      SplitIoClient::Engine::Common::ImpressionManager.new(config,
                                                           repository,
                                                           impression_counter,
                                                           telemetry_runtime_producer,
                                                           impression_observer,
                                                           unique_keys_tracker)
    end

    before :each do
      Redis.new.flushall
      params = { attributes: {}, time: 1_478_113_516_002 }
      params2 = { attributes: {}, time: 1_478_113_518_285 }
      impressions = []
      impressions << { :impression => impressions_manager.build_impression('matching_key', 'foo1', 'foo1', treatment1, false, params), :disabled => false }
      impressions << { :impression => impressions_manager.build_impression('matching_key2', 'foo2', 'foo2', treatment2, false, params2), :disabled => false }
      impressions_manager.track(impressions)
    end

    it 'returns the total number of impressions' do
      expect(sender.send(:impressions_api).total_impressions(formatted_impressions)).to eq(2)
    end

    it 'post impressions with corresponding impressions metadata' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .to_return(status: 200, body: 'ok')

      sender.call

      sleep 0.5
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/bulk')
      .with(
        headers: { 'SplitSDKImpressionsMode' => config.impressions_mode.to_s },
        body: [
          {
            f: 'foo1',
            i: [
              {
                k: 'matching_key',
                t: 'on',
                m: 1_478_113_516_002,
                b: 'foo1',
                r: 'custom_label1',
                c: 123_456,
                pt: nil
              }
            ]
          },
          {
            f: 'foo2',
            i: [
              {
                k: 'matching_key2',
                t: 'off',
                m: 1_478_113_518_285,
                b: 'foo2',
                r: 'custom_label2',
                c: 123_499,
                pt: nil
              }
            ]
          }
        ].to_json
      )).to have_been_made
    end

    it 'calls #post_impressions upon destroy' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk').to_return(status: 200, body: '')

      sender.call
      sleep 0.1
      sender_thread = config.threads[:impressions_sender]
      sender_thread.raise(SplitIoClient::SDKShutdownException)
      sleep 1

      expect(a_request(:post, 'https://events.split.io/api/testImpressions/bulk')).to have_been_made
    end
  end

  describe 'with Memory Adapter' do
    it_behaves_like 'Impressions Sender', :memory
  end

  describe 'with Redis Adapter' do
    it_behaves_like 'Impressions Sender', :redis
  end
end
