# frozen_string_literal: true

require 'spec_helper'
require 'my_impression_listener'

describe SplitIoClient::Engine::Common::ImpressionManager do
  subject { SplitIoClient::Engine::Common::ImpressionManager }

  let(:log) { StringIO.new }
  let(:impression_listener) { MyImpressionListener.new }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:unique_cache) { Concurrent::Hash.new }
  let(:unique_keys_tracker) do
    bf = BloomFilter::Native.new(size: 100, hashes: 2, seed: 1, bucket: 3, raise: false)
    filter_adapter = SplitIoClient::Cache::Filter::FilterAdapter.new(config, bf)
    api_key = 'ImpressionManager-key'
    telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, api_key, telemetry_runtime_producer)
    sender_adapter = SplitIoClient::Cache::Senders::UniqueKeysSenderAdapter.new(config, telemetry_api)

    SplitIoClient::Engine::Impressions::UniqueKeysTracker.new(config,
                                                              filter_adapter,
                                                              sender_adapter,
                                                              unique_cache)
  end
  let(:impression_router) { SplitIoClient::ImpressionRouter.new(config) }

  context 'impressions in none mode' do
    let(:config) do
      SplitIoClient::SplitConfig.new(logger: Logger.new(log),
                                     impression_listener: impression_listener,
                                     impressions_mode: :none,
                                     impressions_queue_size: 10)
    end
    let(:ip) { config.machine_ip }
    let(:machine_name) { config.machine_name }
    let(:version) { "#{config.language}-#{config.version}" }
    let(:impression_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
    let(:impression_manager) do
      subject.new(config,
                  impression_repository,
                  impression_counter,
                  telemetry_runtime_producer,
                  impression_observer,
                  unique_keys_tracker,
                  impression_router)
    end

    it 'build & track impression' do
      expected =
        {
          m: { s: version, i: ip, n: machine_name },
          i: {
            k: 'matching_key_test',
            b: 'bucketing_key_test',
            f: 'split_name_test',
            t: 'off',
            r: 'default label',
            c: 1_478_113_516_002,
            m: 1_478_113_516_222,
            pt: nil
          },
          attributes: {}
        }
      treatment = { treatment: 'off', label: 'default label', change_number: 1_478_113_516_002 }
      params = { attributes: {}, time: 1_478_113_516_222 }

      impression = impression_manager.build_impression('matching_key_test',
                                                       'bucketing_key_test',
                                                       'split_name_test',
                                                       treatment,
                                                       params)
      expect(impression).to match(expected)

      result_count = impression_counter.pop_all
      expect(result_count['split_name_test::1478113200000']).to eq(1)
      expect(unique_cache['split_name_test'].size).to eq(1)

      impression_manager.track([impression])

      sleep 0.5
      expect(impression_repository.batch.size).to eq(0)
      expect(impression_listener.size).to eq(1)
    end
  end

  context 'impressions in optimized mode' do
    let(:config) do
      SplitIoClient::SplitConfig.new(logger: Logger.new(log),
                                     impression_listener: impression_listener,
                                     impressions_queue_size: 10)
    end
    let(:ip) { config.machine_ip }
    let(:machine_name) { config.machine_name }
    let(:version) { "#{config.language}-#{config.version}" }
    let(:impression_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
    let(:impression_manager) do
      subject.new(config,
                  impression_repository,
                  impression_counter,
                  telemetry_runtime_producer,
                  impression_observer,
                  unique_keys_tracker,
                  impression_router)
    end
    let(:expected) do
      {
        m: { s: version, i: ip, n: machine_name },
        i: {
          k: 'matching_key_test',
          b: 'bucketing_key_test',
          f: 'split_name_test',
          t: 'off',
          r: 'default label',
          c: 1_478_113_516_002,
          m: 1_478_113_516_222,
          pt: nil
        },
        attributes: {}
      }
    end

    it 'build impression' do
      treatment = { treatment: 'off', label: 'default label', change_number: 1_478_113_516_002 }
      params = { attributes: {}, time: 1_478_113_516_222 }

      res = impression_manager.build_impression('matching_key_test', 'bucketing_key_test', 'split_name_test', treatment, params)

      expect(res).to match(expected)
    end

    it 'track' do
      impressions = []
      impressions << expected

      impression_manager.track(impressions)

      sleep(0.5)
      expect(impression_repository.batch.size).to eq(1)
      expect(impression_listener.size).to eq(1)
    end

    it 'track optimized' do
      impressions = []

      treatment_data = { treatment: 'off', label: 'default label', change_number: 1_478_113_516_002 }
      params = { attributes: {}, time: expected[:i][:m] }
      imp = expected[:i]

      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)

      impressions << impression_manager.build_impression('second_key', imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], imp[:f], treatment_data, params)

      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)

      impression_manager.track(impressions)

      sleep(0.5)
      expect(impression_repository.batch.size).to eq(3)
      expect(impression_listener.size).to eq(8)
    end

    it 'telemetry' do
      runtime_consumer = SplitIoClient::Telemetry::RuntimeConsumer.new(config)
      impressions = []

      treatment_data = { treatment: 'off', label: 'default label', change_number: 1_478_113_516_002 }
      params = { attributes: {}, time: expected[:i][:m] }
      imp = expected[:i]

      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)

      impressions << impression_manager.build_impression('second_key', imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], imp[:f], treatment_data, params)

      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)

      impressions << impression_manager.build_impression('other_key', imp[:b], 'test_split', treatment_data, params)

      impressions << impression_manager.build_impression('other_key-1', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-2', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-3', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-4', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-5', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-6', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-7', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-8', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('other_key-9', imp[:b], 'test_split', treatment_data, params)

      impression_manager.track(impressions)

      sleep(0.5)
      expect(runtime_consumer.impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_DROPPED)).to be(3)
      expect(runtime_consumer.impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_QUEUED)).to be(10)
      expect(runtime_consumer.impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_DEDUPE)).to be(7)
    end
  end

  context 'impressions in debug mode' do
    let(:config) do
      SplitIoClient::SplitConfig.new(logger: Logger.new(log),
                                     impression_listener: impression_listener,
                                     impressions_mode: :debug,
                                     impressions_queue_size: 10)
    end
    let(:ip) { config.machine_ip }
    let(:machine_name) { config.machine_name }
    let(:version) { "#{config.language}-#{config.version}" }
    let(:impression_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:impression_observer) { SplitIoClient::Observers::ImpressionObserver.new }
    let(:impression_manager) do
      subject.new(config,
                  impression_repository,
                  impression_counter,
                  telemetry_runtime_producer,
                  impression_observer,
                  unique_keys_tracker,
                  impression_router)
    end
    let(:expected) do
      {
        m: { s: version, i: ip, n: machine_name },
        i: {
          k: 'matching_key_test',
          b: 'bucketing_key_test',
          f: 'split_name_test',
          t: 'off',
          r: 'default label',
          c: 1_478_113_516_002,
          m: 1_478_113_516_222,
          pt: nil
        },
        attributes: {}
      }
    end

    it 'telemetry' do
      impressions = []

      treatment_data = { treatment: 'off', label: 'default label', change_number: 1_478_113_516_002 }
      params = { attributes: {}, time: expected[:i][:m] }
      imp = expected[:i]

      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression(imp[:k], imp[:b], imp[:f], treatment_data, params)

      impressions << impression_manager.build_impression('second_key', imp[:b], imp[:f], treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], imp[:f], treatment_data, params)

      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)
      impressions << impression_manager.build_impression('second_key', imp[:b], 'test_split', treatment_data, params)

      impressions << impression_manager.build_impression('other_key', imp[:b], 'test_split', treatment_data, params)

      impression_manager.track(impressions)

      sleep(0.5)
      expect(runtime_consumer.impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_DROPPED)).to be(1)
      expect(runtime_consumer.impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_QUEUED)).to be(10)
      expect(runtime_consumer.impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_DEDUPE)).to be(0)
    end
  end
end
