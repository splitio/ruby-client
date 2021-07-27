# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Segments do
  let(:config) do
    SplitIoClient::SplitConfig.new(
      logger: Logger.new(log),
      debug_enabled: true,
      transport_debug_enabled: true
    )
  end
  let(:log) { StringIO.new }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:segments_api) { described_class.new('', segments_repository, config, telemetry_runtime_producer) }
  let(:adapter) do
    SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new)
  end
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
  let(:segments) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/segments.json')))
  end

  context '#fetch_segments' do
    it 'returns fetch_segments - checking headers when cache_control_headers is false' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .with(headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip',
                'Authorization' => 'Bearer',
                'Connection' => 'keep-alive',
                'Keep-Alive' => '30',
                'Splitsdkversion' => "#{config.language}-#{config.version}"
              })
        .to_return(status: 200, body: segments)

      returned_segment = segments_api.send(:fetch_segment_changes, 'employees', -1)

      expect(returned_segment[:name]).to eq 'employees'

      expect(log.string).to include "'employees' segment retrieved."
      expect(log.string).to include "'employees' 2 added keys"
      expect(log.string).to include ':added=>["max", "dan"]'
    end

    it 'returns fetch_segments - with till param' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1&till=222334')
        .with(headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip',
                'Authorization' => 'Bearer',
                'Connection' => 'keep-alive',
                'Keep-Alive' => '30',
                'Splitsdkversion' => "#{config.language}-#{config.version}"
              })
        .to_return(status: 200, body: segments)

      fetch_options = { cache_control_headers: false, till: 222_334 }
      returned_segment = segments_api.send(:fetch_segment_changes, 'employees', -1, fetch_options)

      expect(returned_segment[:name]).to eq 'employees'

      expect(log.string).to include "'employees' segment retrieved."
      expect(log.string).to include "'employees' 2 added keys"
      expect(log.string).to include ':added=>["max", "dan"]'
    end

    it 'returns fetch_segments - checking headers when cache_control_headers is true' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .with(headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip',
                'Authorization' => 'Bearer',
                'Connection' => 'keep-alive',
                'Keep-Alive' => '30',
                'Splitsdkversion' => "#{config.language}-#{config.version}",
                'Cache-Control' => 'no-cache'
              })
        .to_return(status: 200, body: segments)

      fetch_options = { cache_control_headers: true, till: nil }
      returned_segment = segments_api.send(:fetch_segment_changes, 'employees', -1, fetch_options)

      expect(returned_segment[:name]).to eq 'employees'

      expect(log.string).to include "'employees' segment retrieved."
      expect(log.string).to include "'employees' 2 added keys"
      expect(log.string).to include ':added=>["max", "dan"]'
    end

    it 'throws exception if request to fetch segments from API returns unexpected status code' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .to_return(status: 404)

      expect { segments_api.send(:fetch_segment_changes, 'employees', -1) }.to raise_error(
        'Split SDK failed to connect to backend to fetch segments'
      )
      expect(log.string).to include 'Unexpected status code while fetching segments'
    end

    it 'throws exception if request to get splits from API fails' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .to_raise(StandardError)

      expect { segments_api.send(:fetch_segment_changes, 'employees', -1) }.to raise_error(
        'Split SDK failed to connect to backend to retrieve information'
      )
    end

    it 'throws exception if request to get splits from API times out' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .to_timeout

      expect { segments_api.send(:fetch_segment_changes, 'employees', -1) }.to raise_error(
        'Split SDK failed to connect to backend to retrieve information'
      )
    end
  end
end
