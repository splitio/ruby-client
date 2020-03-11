# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Engine::AuthApiClient do
  subject { SplitIoClient::Engine::AuthApiClient }

  let(:body_response) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/auth_body_response.json'))
  end

  let(:api_key) { 'api-key-test' }
  let(:log) { StringIO.new }
  let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }

  it 'authenticate success' do
    stub_request(:get, config.auth_service_url).to_return(status: 200, body: body_response)

    auth_api_client = subject.new(config)
    response = auth_api_client.authenticate(api_key)

    expect(response[:push_enabled]).to eq(true)
    expect(response[:channels]).to eq('NzM2MDI5Mzc0_MzQyODU4NDUyNg==_segments,NzM2MDI5Mzc0_MzQyODU4NDUyNg==_splits,control')
    expect(response[:retry]).to eq(false)
  end

  it 'auth server return 500' do
    stub_request(:get, config.auth_service_url).to_return(status: 500)

    auth_api_client = subject.new(config)
    response = auth_api_client.authenticate(api_key)

    expect(response[:push_enabled]).to eq(false)
    expect(response[:retry]).to eq(true)
  end

  it 'auth server return 401' do
    stub_request(:get, config.auth_service_url).to_return(status: 401)

    auth_api_client = subject.new(config)
    response = auth_api_client.authenticate(api_key)

    expect(response[:push_enabled]).to eq(false)
    expect(response[:retry]).to eq(false)
  end
end
