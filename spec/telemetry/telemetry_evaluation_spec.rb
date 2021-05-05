# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::EvaluationConsumer do
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:storage) { SplitIoClient::Telemetry::Storages::Memory.new }
  let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config, storage) }
  let(:evaluation_consumer) { SplitIoClient::Telemetry::EvaluationConsumer.new(config, storage) }

  it 'record and pop latencies - should return 3' do  
    latencies = evaluation_consumer.pop_latencies
    expect(latencies.length).to eq(0)

    evaluation_producer.record_latency('get_treatment', 123)
    evaluation_producer.record_latency('get_treatment', 5555)
    evaluation_producer.record_latency('get_treatments', 4444)
    evaluation_producer.record_latency('get_treatment_with_config', 222)

    latencies = evaluation_consumer.pop_latencies

    expect(latencies.length).to eq(3)
    expect(latencies['get_treatment'].length).to eq(2)
    expect(latencies['get_treatments'].length).to eq(1)
    expect(latencies['get_treatment_with_config'].length).to eq(1)

    latencies = evaluation_consumer.pop_latencies

    expect(latencies.length).to eq(0)
  end

  it 'record and pop exceptions - should return 2' do
    exceptions = evaluation_consumer.pop_exceptions
    expect(exceptions.length).to eq(0)

    evaluation_producer.record_exception('get_treatment')
    evaluation_producer.record_exception('get_treatment')
    evaluation_producer.record_exception('get_treatments')

    exceptions = evaluation_consumer.pop_exceptions

    expect(exceptions.length).to eq(2)
    expect(exceptions['get_treatment']).to eq(2)
    expect(exceptions['get_treatments']).to eq(1)

    exceptions = evaluation_consumer.pop_exceptions

    expect(exceptions.length).to eq(0)
  end
end
