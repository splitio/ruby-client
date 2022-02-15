# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::AuthApiClient do
  subject { SplitIoClient::Engine::AuthApiClient }

  let(:body_response) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/auth_body_response.json'))
  end

  let(:api_key) { 'AuthApiClient-key' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
  let(:telemetry_runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }

  it 'authenticate success' do
    stub_request(:get, config.auth_service_url).to_return(status: 200, body: body_response)

    auth_api_client = subject.new(config, telemetry_runtime_producer)
    response = auth_api_client.authenticate(api_key)

    expect(response[:push_enabled]).to eq(true)
    expect(response[:channels]).to eq('xxxx_xxxx_segments%2Cxxxx_xxxx_splits%2C%5B%3Foccupancy%3Dmetrics.publishers%5Dcontrol_pri%2C%5B%3Foccupancy%3Dmetrics.publishers%5Dcontrol_sec')
    expect(response[:retry]).to eq(false)
  end

  it 'auth server return 500' do
    stub_request(:get, config.auth_service_url).to_return(status: 500)

    auth_api_client = subject.new(config, telemetry_runtime_producer)
    response = auth_api_client.authenticate(api_key)

    expect(response[:push_enabled]).to eq(false)
    expect(response[:retry]).to eq(true)
  end

  it 'auth server return 401' do
    stub_request(:get, config.auth_service_url).to_return(status: 401)

    auth_api_client = subject.new(config, telemetry_runtime_producer)
    response = auth_api_client.authenticate(api_key)

    expect(response[:push_enabled]).to eq(false)
    expect(response[:retry]).to eq(false)
  end
end
