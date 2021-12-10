# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::EvaluationConsumer do
  let(:log) { StringIO.new }

  context 'Memory' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
    let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
    let(:evaluation_consumer) { SplitIoClient::Telemetry::EvaluationConsumer.new(config) }

    it 'record and pop latencies' do
      latencies = evaluation_consumer.pop_latencies
      expect(latencies.length).to eq(5)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TRACK].length).to eq(23)

      evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 1)
      evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 2)
      evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS, 3)
      evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG, 4)

      latencies = evaluation_consumer.pop_latencies

      expect(latencies.length).to eq(5)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT][1]).to eq(1)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT][2]).to eq(1)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS][3]).to eq(1)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG][4]).to eq(1)

      latencies = evaluation_consumer.pop_latencies

      expect(latencies.length).to eq(5)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG].length).to eq(23)
      expect(latencies[SplitIoClient::Telemetry::Domain::Constants::TRACK].length).to eq(23)
    end

    it 'record and pop exceptions' do
      exceptions = evaluation_consumer.pop_exceptions
      expect(exceptions.length).to eq(5)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENT]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TRACK]).to eq(0)

      evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)
      evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)
      evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS)

      exceptions = evaluation_consumer.pop_exceptions
      expect(exceptions.length).to eq(5)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENT]).to eq(2)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS]).to eq(1)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TRACK]).to eq(0)

      exceptions = evaluation_consumer.pop_exceptions

      expect(exceptions.length).to eq(5)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENT]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG]).to eq(0)
      expect(exceptions[SplitIoClient::Telemetry::Domain::Constants::TRACK]).to eq(0)
    end
  end

  context 'Redis' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), cache_adapter: :redis) }
    let(:adapter) { config.telemetry_adapter }
    let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
    let(:latency_key) { 'SPLITIO.telemetry.latencies' }
    let(:exception_key) { 'SPLITIO.telemetry.exceptions' }
    let(:sdk_version) { "#{config.language}-#{config.version}" }
    let(:name) { config.machine_name }
    let(:ip) { config.machine_ip }

    it 'record latency' do
      adapter.redis.del(latency_key)

      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 123)).to eq(1)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 5555)).to eq(1)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS, 4444)).to eq(1)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG, 222)).to eq(1)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG, 2)).to eq(1)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TRACK, 3)).to eq(1)

      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 123)).to eq(2)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 5555)).to eq(2)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS, 4444)).to eq(2)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG, 222)).to eq(2)

      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 123)).to eq(3)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 5555)).to eq(3)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS, 4444)).to eq(3)
      expect(evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG, 222)).to eq(3)

      expect(adapter.redis.hget(latency_key, "#{sdk_version}/#{name}/#{ip}/treatment/123").to_i).to eq(3)
      expect(adapter.redis.hget(latency_key, "#{sdk_version}/#{name}/#{ip}/treatments/4444").to_i).to eq(3)
      expect(adapter.redis.hget(latency_key, "#{sdk_version}/#{name}/#{ip}/treatmentWithConfig/222").to_i).to eq(3)
      expect(adapter.redis.hget(latency_key, "#{sdk_version}/#{name}/#{ip}/treatmentsWithConfig/2").to_i).to eq(1)
      expect(adapter.redis.hget(latency_key, "#{sdk_version}/#{name}/#{ip}/track/3").to_i).to eq(1)
    end

    it 'record exception' do
      adapter.redis.del(exception_key)

      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)).to eq(1)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)).to eq(2)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS)).to eq(1)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS)).to eq(2)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS)).to eq(3)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)).to eq(3)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG)).to eq(1)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG)).to eq(1)
      expect(evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TRACK)).to eq(1)

      expect(adapter.redis.hget(exception_key, "#{sdk_version}/#{name}/#{ip}/treatment").to_i).to eq(3)
      expect(adapter.redis.hget(exception_key, "#{sdk_version}/#{name}/#{ip}/treatments").to_i).to eq(3)
      expect(adapter.redis.hget(exception_key, "#{sdk_version}/#{name}/#{ip}/treatmentWithConfig").to_i).to eq(1)
      expect(adapter.redis.hget(exception_key, "#{sdk_version}/#{name}/#{ip}/treatmentsWithConfig").to_i).to eq(1)
      expect(adapter.redis.hget(exception_key, "#{sdk_version}/#{name}/#{ip}/track").to_i).to eq(1)
    end
  end
end
