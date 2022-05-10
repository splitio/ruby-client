# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::InitConsumer do
  let(:log) { StringIO.new }

  context 'Memory' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
    let(:init_producer) { SplitIoClient::Telemetry::InitProducer.new(config) }
    let(:init_consumer) { SplitIoClient::Telemetry::InitConsumer.new(config) }

    it 'record and get bur timeouts' do
      result = init_consumer.bur_timeouts

      expect(result).to eq(0)

      init_producer.record_bur_timeout
      init_producer.record_bur_timeout
      init_producer.record_bur_timeout

      result = init_consumer.bur_timeouts

      expect(result).to eq(3)

      init_producer.record_bur_timeout

      result = init_consumer.bur_timeouts

      expect(result).to eq(4)
    end

    it 'record and get non ready usages' do
      result = init_consumer.non_ready_usages

      expect(result).to eq(0)

      init_producer.record_non_ready_usages
      init_producer.record_non_ready_usages
      init_producer.record_non_ready_usages
      init_producer.record_non_ready_usages

      result = init_consumer.non_ready_usages

      expect(result).to eq(4)

      init_producer.record_non_ready_usages

      result = init_consumer.non_ready_usages

      expect(result).to eq(5)
    end
  end

  context 'Redis' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), cache_adapter: :redis, redis_namespace: 'telemetry-test') }
    let(:adapter) { config.telemetry_adapter }
    let(:init_producer) { SplitIoClient::Telemetry::InitProducer.new(config) }
    let(:telemetry_config_key) { 'telemetry-test.SPLITIO.telemetry.init' }

    it 'record config_init' do
      adapter.redis.del(telemetry_config_key)

      config_init = SplitIoClient::Telemetry::ConfigInit.new('CONSUMER', 'REDIS', 1, 0, %w[t1 t2])

      init_producer.record_config(config_init)

      field = "#{config.language}-#{config.version}/#{config.machine_name}/#{config.machine_ip}"
      result = JSON.parse(adapter.find_in_map(telemetry_config_key, field), symbolize_names: true)

      expect(result[:t][:oM]).to eq('CONSUMER')
      expect(result[:t][:st]).to eq('REDIS')
      expect(result[:t][:aF]).to eq(1)
      expect(result[:t][:rF]).to eq(0)
      expect(result[:t][:t]).to eq(%w[t1 t2])

      adapter.redis.del(telemetry_config_key)
    end

    it 'record config_init when data is nil' do
      adapter.redis.del(telemetry_config_key)

      init_producer.record_config(nil)

      result = adapter.redis.lrange(telemetry_config_key, 0, -1)

      expect(result.empty?).to be true

      adapter.redis.del(telemetry_config_key)
    end
  end
end
