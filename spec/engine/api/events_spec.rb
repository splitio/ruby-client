# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Events do
  let(:config) do
    SplitIoClient::SplitConfig.new(
      logger: Logger.new(log),
      debug_enabled: true,
      transport_debug_enabled: true
    )
  end
  let(:log) { StringIO.new }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:events_api) { described_class.new('', config, telemetry_runtime_producer) }
  let(:events) do
    [{
      e: {
        key: 'key',
        trafficTypeName: 'trafficTypeName',
        eventTypeId: 'eventTypeId',
        value: '1.1',
        timestamp: Time.now
      },
      m: {
        i: '127.0.0.1',
        n: 'MachineName',
        s: '1.0.0'
      }
    }]
  end

  context '#post' do
    it 'post events' do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: 200, body: 'ok')

      events_api.post(events)

      expect(log.string).to include 'Events reported: 1'
    end

    it 'throws exception if request to post latencies returns unexpected status code' do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_return(status: 404)

      expect { events_api.post(events) }.to raise_error(
        'Split SDK failed to connect to backend to post events'
      )
      expect(log.string).to include 'Unexpected status code while posting events: 404.' \
      ' - Check your API key and base URI'
    end

    it 'throws exception if request to post metrics fails' do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_raise(StandardError)

      expect { events_api.post(events) }.to raise_error(
        'Split SDK failed to connect to backend to post information'
      )
    end

    it 'throws exception if request to post metrics times out' do
      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .to_timeout

      expect { events_api.post(events) }.to raise_error(
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

      api = described_class.new('', custom_config, telemetry_runtime_producer)

      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json',
                'SplitSDKMachineIP' => config.machine_ip,
                'SplitSDKMachineName' => config.machine_name
              })
        .to_return(status: [500, 'Internal Server Error'])

      stub_request(:post, 'https://events.split.io/api/events/bulk')
        .with(headers: {
                'Authorization' => 'Bearer',
                'SplitSDKVersion' => "#{config.language}-#{config.version}",
                'Content-Type' => 'application/json'
              })
        .to_return(status: 200, body: 'ok')

      api.post(events)
      expect(log.string).to include 'Events reported: 1'
    end
  end
end
