# frozen_string_literal: true

require 'spec_helper'
require 'bloomfilter-rb'

describe SplitIoClient::SplitClient do
  let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 10) }

  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
  let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
  let(:bf) { BloomFilter::Native.new(size: 100, hashes: 2, seed: 1, bucket: 3, raise: false) }
  let(:filter_adapter) { SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf) }
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:api_key) { 'SplitClient-key' }
  let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer) }
  let(:sender_adapter) { SplitIoClient::Cache::Senders::UniqueKeysSenderAdapter.new(config, telemetry_api) }
  let(:unique_keys_tracker) do
    SplitIoClient::Engine::Impressions::UniqueKeysTracker.new(config,
                                                              filter_adapter,
                                                              sender_adapter,
                                                              Concurrent::Hash.new)
  end
  let(:impression_router) { SplitIoClient::ImpressionRouter.new(config) }
  let(:impressions_manager) do
    SplitIoClient::Engine::Common::ImpressionManager.new(config,
                                                         impressions_repository,
                                                         impression_counter,
                                                         evaluation_producer,
                                                         impression_observer,
                                                         unique_keys_tracker,
                                                         impression_router)
  end
  let(:client) do
    repositories = { splits: splits_repository, segments: segments_repository, impressions: impressions_repository, events: nil }
    SplitIoClient::SplitClient.new('', repositories, nil, config, impressions_manager, evaluation_producer)
  end

  context 'control' do
    it 'allocates minimum objects' do
      expect { client.get_treatment('key', 'key') }.to allocate_max(91).objects
    end
  end
end
