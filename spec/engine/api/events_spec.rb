# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Events do
  before do
    SplitIoClient.configuration.logger = Logger.new(log)
    SplitIoClient.configuration.debug_enabled = true
    SplitIoClient.configuration.transport_debug_enabled = true
  end

  let(:log) { StringIO.new }
  let(:events_api) { described_class.new('') }
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
  end
end
