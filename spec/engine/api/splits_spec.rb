# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Splits do
  let(:config) do
    SplitIoClient::SplitConfig.new(
      logger: Logger.new(log),
      debug_enabled: true,
      transport_debug_enabled: true
    )
  end

  let(:log) { StringIO.new }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:splits_api) { described_class.new('', config, telemetry_runtime_producer) }
  let(:splits) { File.read(File.expand_path(File.join(File.dirname(__FILE__), '../../test_data/splits/splits.json'))) }

  context '#splits_with_segment_names' do
    it 'returns splits with segment names' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 200, body: splits)

      parsed_splits = splits_api.send(:splits_with_segment_names, splits)

      expect(parsed_splits[:segment_names]).to eq(Set.new(%w[demo employees]))
    end
  end

  context '#since' do
    it 'returns the splits - checking headers when cache_control_headers is false' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .with(headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip',
                'Authorization' => 'Bearer',
                'Connection' => 'keep-alive',
                'Keep-Alive' => '30',
                'Splitsdkversion' => "#{config.language}-#{config.version}"
              })
        .to_return(status: 200, body: splits)

      returned_splits = splits_api.since(-1)
      expect(returned_splits[:segment_names]).to eq(Set.new(%w[demo employees]))

      expect(log.string).to include '2 splits retrieved. since=-1'
      expect(log.string).to include returned_splits.to_s
    end

    it 'returns the splits - with till param' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1&till=123123')
        .with(headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip',
                'Authorization' => 'Bearer',
                'Connection' => 'keep-alive',
                'Keep-Alive' => '30',
                'Splitsdkversion' => "#{config.language}-#{config.version}"
              })
        .to_return(status: 200, body: splits)

      fetch_options = { cache_control_headers: false, till: 123_123 }
      returned_splits = splits_api.since(-1, fetch_options)
      expect(returned_splits[:segment_names]).to eq(Set.new(%w[demo employees]))

      expect(log.string).to include '2 splits retrieved. since=-1'
      expect(log.string).to include returned_splits.to_s
    end

    it 'returns the splits - checking headers when cache_control_headers is true' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .with(headers: {
                'Accept' => '*/*',
                'Accept-Encoding' => 'gzip',
                'Authorization' => 'Bearer',
                'Connection' => 'keep-alive',
                'Keep-Alive' => '30',
                'Splitsdkversion' => "#{config.language}-#{config.version}",
                'Cache-Control' => 'no-cache'
              })
        .to_return(status: 200, body: splits)

      fetch_options = { cache_control_headers: true, till: nil }
      returned_splits = splits_api.since(-1, fetch_options)
      expect(returned_splits[:segment_names]).to eq(Set.new(%w[demo employees]))

      expect(log.string).to include '2 splits retrieved. since=-1'
      expect(log.string).to include returned_splits.to_s
    end

    it 'throws exception if request to get splits from API returns unexpected status code' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_return(status: 404)

      expect { splits_api.since(-1) }.to raise_error(
        'Split SDK failed to connect to backend to fetch split definitions'
      )
      expect(log.string).to include 'Unexpected status code while fetching splits'
    end

    it 'throws exception if request to get splits from API fails' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_raise(StandardError)

      expect { splits_api.since(-1) }.to raise_error(
        'Split SDK failed to connect to backend to retrieve information'
      )
    end

    it 'throws exception if request to get splits from API times out' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
        .to_timeout

      expect { splits_api.since(-1) }.to raise_error(
        'Split SDK failed to connect to backend to retrieve information'
      )
    end
  end
end
