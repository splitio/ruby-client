# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitClient do
  let(:config) { SplitIoClient::SplitConfig.new(impressions_queue_size: 10) }

  let(:request_decorator) { SplitIoClient::Api::RequestDecorator.new(nil) }
  let(:flag_sets_repository) {SplitIoClient::Cache::Repositories::MemoryFlagSetsRepository.new([])}
  let(:flag_set_filter) {SplitIoClient::Cache::Filter::FlagSetsFilter.new([])}
  let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config, flag_sets_repository, flag_set_filter) }
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:impressions_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
  let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
  let(:bf) { SplitIoClient::Cache::Filter::BloomFilter.new(1_000) }
  let(:filter_adapter) { SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf) }
  let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:api_key) { 'SplitClient-key' }
  let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer, request_decorator) }
  let(:impressions_api) { SplitIoClient::Api::Impressions.new(api_key, config, runtime_producer, request_decorator) }
  let(:evaluator) { SplitIoClient::Engine::Parser::Evaluator.new(segments_repository, splits_repository, config) }
  let(:sender_adapter) do
    SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config,
                                                                telemetry_api,
                                                                impressions_api)
  end
  let(:unique_keys_tracker) do
    SplitIoClient::Engine::Impressions::UniqueKeysTracker.new(config,
                                                              filter_adapter,
                                                              sender_adapter,
                                                              Concurrent::Hash.new)
  end
  let(:impressions_manager) do
    SplitIoClient::Engine::Common::ImpressionManager.new(config,
                                                         impressions_repository,
                                                         impression_counter,
                                                         evaluation_producer,
                                                         impression_observer,
                                                         unique_keys_tracker)
  end
  let(:client) do
    SplitIoClient::SplitClient.new('', {:splits => splits_repository, :segments => segments_repository, :impressions => impressions_repository, :events => nil}, nil, config, impressions_manager, evaluation_producer, evaluator, SplitIoClient::Validators.new(config))
  end

  context 'control' do
    it 'allocates minimum objects' do
      expect { client.get_treatment('key', 'key') }.to allocate_max(91).objects
    end
  end
end
