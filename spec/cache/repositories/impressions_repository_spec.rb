# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'Impressions Repository' do
    let(:ip) { config.machine_ip }
    let(:machine_name) { config.machine_name }
    let(:version) do
      "#{config.language}-#{config.version}"
    end

    let(:treatment1) { { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 } }
    let(:treatment2) { { treatment: 'off', label: 'sample_rule', change_number: 1_533_177_602_749 } }
    let(:result) do
      [
        {
          m: { s: version, i: ip, n: machine_name },
          i: {
            k: 'matching_key1',
            b: nil,
            f: :foo,
            t: 'on',
            r: 'sample_rule',
            c: 1_533_177_602_748,
            m: 1_478_113_516_002,
            pt: nil
          },
          attributes: {}
        },
        {
          m: { s: version, i: ip, n: machine_name },
          i: {
            k: 'matching_key1',
            b: nil,
            f: :bar,
            t: 'off',
            r: 'sample_rule',
            c: 1_533_177_602_749,
            m: 1_478_113_516_002,
            pt: nil
          },
          attributes: {}
        }
      ]
    end

    before :each do
      config.labels_enabled = true
      config.impressions_bulk_size = 2
      Redis.new.flushall
    end

    it 'adds impressions' do
      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key1', nil, :foo, treatment1, params)
      impressions << impressions_manager.build_impression('matching_key1', nil, :bar, treatment2, params)
      impressions_manager.track(impressions)

      expect(repository.batch).to match_array(result)

      expect(repository.batch).to eq([])
    end

    it 'adds impressions in bulk' do
      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key1', nil, :foo, treatment1, params)
      impressions << impressions_manager.build_impression('matching_key1', nil, :bar, treatment2, params)
      impressions_manager.track(impressions)

      expect(repository.batch).to match_array(result)

      expect(repository.batch).to eq([])
    end

    it 'omits label unless labels_enabled' do
      config.labels_enabled = false
      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key1', nil, :foo, treatment1, params)
      impressions_manager.track(impressions)

      expect(repository.batch.first[:i][:r]).to be_nil
    end

    it 'bulk size less than the actual queue' do
      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key1', nil, :foo, treatment1, params)
      impressions << impressions_manager.build_impression('matching_key1', nil, :foo, treatment2, params)
      impressions_manager.track(impressions)

      config.impressions_bulk_size = 1

      expect(repository.batch.size).to eq(1)
      expect(repository.batch.size).to eq(1)
    end
  end

  describe 'with Memory Adapter' do
    let(:config) { @default_config }

    let(:repository) { described_class.new(config) }
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
    let(:unique_keys_tracker) do
      bf = SplitIoClient::Cache::Filter::BloomFilter.new(1_000)
      filter_adapter = SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf)
      api_key = 'ImpressionsRepository-memory-key'
      telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer)
      impressions_api = SplitIoClient::Api::Impressions.new(api_key, config, runtime_producer)
      sender_adapter = SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impressions_api)

      SplitIoClient::Engine::Impressions::UniqueKeysTracker.new(config,
                                                                filter_adapter,
                                                                sender_adapter,
                                                                Concurrent::Hash.new)
    end
    let(:impression_router) { SplitIoClient::ImpressionRouter.new(config) }
    let(:impressions_manager) do
      SplitIoClient::Engine::Common::ImpressionManager.new(config,
                                                           repository,
                                                           impression_counter,
                                                           runtime_producer,
                                                           impression_observer,
                                                           unique_keys_tracker,
                                                           impression_router)
    end

    it_behaves_like 'Impressions Repository'

    context 'number of impressions is greater than queue size' do
      let(:config) do
        SplitIoClient::SplitConfig.new(
          impressions_queue_size: 1
        )
      end

      it 'memory adapter drops impressions' do
        treatment = { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 }
        params = { attributes: {}, time: 1_478_113_516_002 }
        impressions = []
        impressions << impressions_manager.build_impression('matching_key1', nil, :foo1, treatment, params)
        impressions << impressions_manager.build_impression('matching_key2', nil, :foo1, treatment, params)
        impressions_manager.track(impressions)

        expect(repository.batch.size).to eq(1)
      end
    end
  end

  describe 'with Redis Adapter' do
    let(:config) do
      SplitIoClient::SplitConfig.new(
        labels_enabled: true,
        impressions_bulk_size: 2,
        cache_adapter: :redis
      )
    end

    let(:repository) { described_class.new(config) }
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
    let(:unique_keys_tracker) do
      bf = SplitIoClient::Cache::Filter::BloomFilter.new(1_000)
      filter_adapter = SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf)
      api_key = 'ImpressionsRepository-key'
      telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer)
      impressions_api = SplitIoClient::Api::Impressions.new(api_key, config, runtime_producer)
      sender_adapter = SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impressions_api)

      SplitIoClient::Engine::Impressions::UniqueKeysTracker.new(config,
                                                                filter_adapter,
                                                                sender_adapter,
                                                                Concurrent::Hash.new)
    end
    let(:impression_router) { SplitIoClient::ImpressionRouter.new(config) }
    let(:impressions_manager) do
      SplitIoClient::Engine::Common::ImpressionManager.new(config,
                                                           repository,
                                                           impression_counter,
                                                           runtime_producer,
                                                           impression_observer,
                                                           unique_keys_tracker,
                                                           impression_router)
    end

    it_behaves_like 'Impressions Repository'

    let(:treatment) { { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 } }

    let(:adapter) { config.impressions_adapter }

    before :each do
      Redis.new.flushall
    end

    it 'expiration set when impressions size match number of elements added' do
      expect(config.impressions_adapter).to receive(:expire).once.with(anything, 3600)
      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key', nil, :foo1, treatment, params)
      impressions << impressions_manager.build_impression('matching_key', nil, :foo1, treatment, params)
      impressions_manager.track(impressions)
    end

    it 'returns empty array when adapter#get_from_queue raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Adapters::RedisAdapter)
        .to receive(:get_from_queue).and_throw(RuntimeError)

      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key', nil, :foo1, treatment, params)
      impressions_manager.track(impressions)

      expect(repository.batch).to eq([])
    end

    it 'with ip_addresses_enabled set true' do
      other_treatment = { treatment: 'on', label: 'sample_rule_2', change_number: 1_533_177_602_748 }
      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << impressions_manager.build_impression('matching_key', nil, :foo1, treatment, params)
      impressions << impressions_manager.build_impression('matching_key', nil, :foo2, other_treatment, params)
      impressions_manager.track(impressions)

      adapter.get_from_queue('SPLITIO.impressions', 0).map do |e|
        impression = JSON.parse(e, symbolize_names: true)
        expect(impression[:m][:i]).to eq config.machine_ip
        expect(impression[:m][:n]).to eq config.machine_name
      end
    end

    it 'with ip_addresses_enabled set false' do
      custom_config = SplitIoClient::SplitConfig.new(
        labels_enabled: true,
        impressions_bulk_size: 2,
        cache_adapter: :redis,
        ip_addresses_enabled: false
      )
      custom_runtime_producer = SplitIoClient::Telemetry::RuntimeProducer.new(custom_config)
      custom_repository = described_class.new(custom_config)
      custom_adapter = config.impressions_adapter
      custom_impressions_manager = SplitIoClient::Engine::Common::ImpressionManager.new(custom_config,
                                                                                        custom_repository,
                                                                                        impression_counter,
                                                                                        custom_runtime_producer,
                                                                                        impression_observer,
                                                                                        unique_keys_tracker,
                                                                                        impression_router)
      other_treatment = { treatment: 'on', label: 'sample_rule_2', change_number: 1_533_177_602_748 }

      params = { attributes: {}, time: 1_478_113_516_002 }
      impressions = []
      impressions << custom_impressions_manager.build_impression('matching_key', nil, :foo1, treatment, params)
      impressions << custom_impressions_manager.build_impression('matching_key', nil, :foo2, other_treatment, params)
      custom_impressions_manager.track(impressions)

      custom_adapter.get_from_queue('SPLITIO.impressions', 0).map do |e|
        impression = JSON.parse(e, symbolize_names: true)

        expect(impression[:m][:i]).to eq 'NA'
        expect(impression[:m][:n]).to eq 'NA'
      end
    end
  end
end
