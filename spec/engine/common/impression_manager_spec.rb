# frozen_string_literal: true

require 'spec_helper'
require 'my_impression_listener'

describe SplitIoClient::Engine::Common::ImpressionManager do
  subject { SplitIoClient::Engine::Common::ImpressionManager }

  let(:log) { StringIO.new }
  let(:impression_listener) { MyImpressionListener.new }
  let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }

  context 'impressions in optimized mode' do
    let(:config) do
      SplitIoClient::SplitConfig.new(logger: Logger.new(log), impression_listener: impression_listener, impressions_queue_size: 10)
    end
    let(:ip) { config.machine_ip }
    let(:machine_name) { config.machine_name }
    let(:version) { "#{config.language}-#{config.version}" }
    let(:impression_repository) { SplitIoClient::Cache::Repositories::ImpressionsRepository.new(config) }
    let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:impression_manager) { subject.new(config, impression_repository, impression_counter, telemetry_runtime_producer) }
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
    let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:impression_manager) { subject.new(config, impression_repository, impression_counter, telemetry_runtime_producer) }
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
