# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Metrics do
  let(:config) do
    SplitIoClient::SplitConfig.new(
      logger: Logger.new(log),
      debug_enabled: true,
      transport_debug_enabled: true,
      metrics_adapter: adapter
    )
  end
  let(:log) { StringIO.new }
  let(:metrics_api) { described_class.new('', metrics_repository, config) }
  let(:adapter) do
    SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new)
  end
  let(:metrics_repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(config) }

  context '#post_latencies' do
    let!(:latency) { metrics_repository.add_latency('latency.test', 12, nil) }
    it 'post latencies' do
      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: 200, body: 'ok')

      metrics_api.send(:post_latencies)
      expect(metrics_repository.latencies.size).to eq 0
    end

    it 'throws exception if request to post latencies returns unexpected status code' do
      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .to_return(status: 404)

      expect { metrics_api.send(:post_latencies) }.to raise_error(
        'Split SDK failed to connect to backend to post metrics'
      )
      expect(log.string).to include 'Unexpected status code while posting time metrics'
    end

    it 'throws exception if request to post metrics fails' do
      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .to_raise(StandardError)

      expect { metrics_api.send(:post_latencies) }.to raise_error(
        'Split SDK failed to connect to backend to post information'
      )
    end

    it 'throws exception if request to post metrics times out' do
      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .to_timeout

      expect { metrics_api.send(:post_latencies) }.to raise_error(
        'Split SDK failed to connect to backend to post information'
      )
    end

    it 'when ip_addresses_enabled is false' do
      custom_config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        transport_debug_enabled: true,
        ip_addresses_enabled: false
      )

      api = described_class.new('', metrics_repository, custom_config)

      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: [500, 'Internal Server Error'])

      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json'
              })
        .to_return(status: 200, body: 'ok')

      api.send(:post_latencies)
      expect(metrics_repository.latencies.size).to eq 0
    end
  end

  context '#post_counts' do
    let!(:count) { metrics_repository.add_count('count.test', 12) }
    it 'post counts' do
      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: 200, body: 'ok')

      metrics_api.send(:post_counts)
      expect(metrics_repository.counts.size).to eq 0
    end

    it 'throws exception if request to post latencies returns unexpected status code' do
      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .to_return(status: 404)

      expect { metrics_api.send(:post_counts) }.to raise_error(
        'Split SDK failed to connect to backend to post metrics'
      )
      expect(log.string).to include 'Unexpected status code while posting time metrics'
    end

    it 'throws exception if request to post metrics fails' do
      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .to_raise(StandardError)

      expect { metrics_api.send(:post_counts) }.to raise_error(
        'Split SDK failed to connect to backend to post information'
      )
    end

    it 'throws exception if request to post metrics times out' do
      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .to_timeout

      expect { metrics_api.send(:post_counts) }.to raise_error(
        'Split SDK failed to connect to backend to post information'
      )
    end

    it 'when ip_addresses_enabled is false' do
      custom_config = SplitIoClient::SplitConfig.new(
        logger: Logger.new(log),
        debug_enabled: true,
        transport_debug_enabled: true,
        ip_addresses_enabled: false
      )

      api = described_class.new('', metrics_repository, custom_config)

      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: [500, 'Internal Server Error'])

      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json'
              })
        .to_return(status: 200, body: 'ok')

      api.send(:post_counts)
      expect(metrics_repository.counts.size).to eq 0
    end
  end

  context '#post' do
    it 'post without latencies nor counters' do
      stub_request(:post, 'https://events.split.io/api/metrics/counter')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: 200, body: 'ok')

      stub_request(:post, 'https://events.split.io/api/metrics/time')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: 200, body: 'ok')

      metrics_api.post
      expect(log.string).to include 'No counts to report.'
      expect(log.string).to include 'No latencies to report.'
    end
  end
end
