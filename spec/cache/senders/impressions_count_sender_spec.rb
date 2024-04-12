# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Senders::ImpressionsCountSender do
  subject { SplitIoClient::Cache::Senders::ImpressionsCountSender }
  let(:request_decorator) { SplitIoClient::Api::RequestDecorator.new(nil) }

  before :each do
    impression_counter.inc('feature1', make_timestamp('2020-09-02 09:15:11'))
    impression_counter.inc('feature1', make_timestamp('2020-09-02 09:20:11'))
    impression_counter.inc('feature1', make_timestamp('2020-09-02 09:50:11'))
    impression_counter.inc('feature2', make_timestamp('2020-09-02 09:50:11'))
    impression_counter.inc('feature2', make_timestamp('2020-09-02 09:55:11'))
    impression_counter.inc('feature1', make_timestamp('2020-09-02 10:50:11'))
  end

  context 'Redis Adapter' do
    let(:config) do
      SplitIoClient::SplitConfig.new(cache_adapter: :redis, redis_namespace: 'prefix-count-test')
    end
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:impressions_sender_adapter) { SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, nil, nil) }
    let(:impressions_count_sender) do
      config.counter_refresh_rate = 0.5
      subject.new(config, impression_counter, impressions_sender_adapter)
    end

    it 'posting impressions count' do
      key = "#{config.redis_namespace}.impressions.count"
      impressions_count_sender.call

      sleep 1

      expect(config.cache_adapter.exists?(key)).to eq(true)

      expect(config.cache_adapter.find_in_map(key, "feature1::#{make_timestamp('2020-09-02 09:00:00')}").to_i).to eq(3)
      expect(config.cache_adapter.find_in_map(key, "feature2::#{make_timestamp('2020-09-02 09:00:00')}").to_i).to eq(2)
      expect(config.cache_adapter.find_in_map(key, "feature1::#{make_timestamp('2020-09-02 10:00:00')}").to_i).to eq(1)

      config.cache_adapter.delete(key)
    end
  end

  context 'Memory Adapter' do
    let(:config) do
      SplitIoClient::SplitConfig.new
    end
    let(:impression_counter) { SplitIoClient::Engine::Common::ImpressionCounter.new }
    let(:impressions_sender_adapter) do
      telemetry_runtime_producer = SplitIoClient::Telemetry::RuntimeProducer.new(config)
      impressions_api = SplitIoClient::Api::Impressions.new('key-test', config, telemetry_runtime_producer, request_decorator)
      telemetry_api = SplitIoClient::Api::TelemetryApi.new(config, 'key-test', telemetry_runtime_producer, request_decorator)

      SplitIoClient::Cache::Senders::ImpressionsSenderAdapter.new(config, telemetry_api, impressions_api)
    end
    let(:impressions_count_sender) do
      config.counter_refresh_rate = 0.5

      subject.new(config, impression_counter, impressions_sender_adapter)
    end

    it 'post impressions count with corresponding impressions count data' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: 'ok')

      impressions_count_sender.call

      sleep 1

      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')
        .with(
          body:
          {
            pf:
            [
              {
                f: 'feature1',
                m: make_timestamp('2020-09-02 09:00:00'),
                rc: 3
              },
              {
                f: 'feature2',
                m: make_timestamp('2020-09-02 09:00:00'),
                rc: 2
              },
              {
                f: 'feature1',
                m: make_timestamp('2020-09-02 10:00:00'),
                rc: 1
              }
            ]
          }.to_json
        )).to have_been_made
    end

    it 'calls #post_impressions upon destroy' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/count').to_return(status: 200, body: '')

      config.counter_refresh_rate = 5
      sender = subject.new(config, impression_counter, impressions_sender_adapter)

      sender.call
      sleep 0.1
      sender_thread = config.threads[:impressions_count_sender]
      sender_thread.raise(SplitIoClient::SDKShutdownException)

      sleep 1
      expect(a_request(:post, 'https://events.split.io/api/testImpressions/count')).to have_been_made
    end
  end

  def make_timestamp(time)
    (Time.parse(time).to_f * 1000.0).to_i
  end
end
