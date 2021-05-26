# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::TelemetryApi do
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), debug_enabled: true, transport_debug_enabled: true) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
  let(:telemetry_api) { described_class.new(config, 'api-key-test', telemetry_runtime_producer) }

  before do
    stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
      .to_return(status: 200, body: 'ok')
  end

  it 'returns splits with segment names' do
    usage = SplitIoClient::Telemetry::Usage.new
    telemetry_api.record_stats(usage)

    expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')).to have_been_made
  end
end
