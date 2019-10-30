# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Impressions do
  let(:config) do
    SplitIoClient::SplitConfig.new(
      logger: Logger.new(log),
      debug_enabled: true,
      transport_debug_enabled: true
    )
  end
  let(:log) { StringIO.new }
  let(:impressions_api) { described_class.new('', config) }
  let(:impressions) do
    [
      {
        ip: '192.168.1.1',
        keyImpressions: ['test']
      }
    ]
  end

  context '#post' do
    it 'post impressions' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: 200, body: 'ok')

      impressions_api.post(impressions)
      expect(log.string).to include 'Impressions reported: 1'
    end

    it 'throws exception if request to post latencies returns unexpected status code' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .to_return(status: 404)

      expect { impressions_api.post(impressions) }.to raise_error(
        'Split SDK failed to connect to backend to post impressions'
      )
      expect(log.string).to include 'Unexpected status code while posting impressions: 404.' \
      ' - Check your API key and base URI'
    end

    it 'throws exception if request to post metrics fails' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .to_raise(StandardError)

      expect { impressions_api.post(impressions) }.to raise_error(
        'Split SDK failed to connect to backend to post information'
      )
    end

    it 'throws exception if request to post metrics times out' do
      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .to_timeout

      expect { impressions_api.post(impressions) }.to raise_error(
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

      api = described_class.new('', custom_config)

      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: [500, 'Internal Server Error'])

      stub_request(:post, 'https://events.split.io/api/testImpressions/bulk')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json'
              })
        .to_return(status: 200, body: 'ok')

      api.post(impressions)
      expect(log.string).to include 'Impressions reported: 1'
    end
  end
end
