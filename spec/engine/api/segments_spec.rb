# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Segments do
  let(:log) { StringIO.new }
  let(:config) do
    SplitIoClient::SplitConfig.new(
      logger: Logger.new(log),
      debug_enabled: true,
      transport_debug_enabled: true
    )
  end
  let(:segments_api) { described_class.new('', config, metrics, segments_repository) }
  let(:adapter) do
    SplitIoClient::Cache::Adapters::MemoryAdapter.new(SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new)
  end
  let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(adapter, config) }
  let(:metrics_repository) { SplitIoClient::Cache::Repositories::MetricsRepository.new(config.metrics_adapter, config) }
  let(:metrics) { SplitIoClient::Metrics.new(100, config, metrics_repository) }
  let(:segments) do
    File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/segments/segments.json')))
  end

  context '#fetch_segments' do
    it 'returns fetch_segments' do
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .to_return(status: 200, body: segments)
      returned_segment = segments_api.send(:fetch_segment_changes, 'employees', -1)

      expect(returned_segment[:name]).to eq 'employees'

      expect(log.string).to include "'employees' segment retrieved."
      expect(log.string).to include "'employees' 2 added keys"
      expect(log.string).to include ':added=>["max", "dan"]'

      expect(metrics_repository.counts).to include 'segmentChangeFetcher.status.200'
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
