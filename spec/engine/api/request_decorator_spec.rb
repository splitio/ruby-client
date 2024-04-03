# frozen_string_literal: true

require 'spec_helper'

class MyCustomDecorator3
  def get_header_overrides(request_context)
      ["value"]
  end
end

class MyCustomDecorator2
  def get_header_overrides(request_context)
      headers = request_context.headers
      headers["UserCustomHeader"] = ["value"]
      for header in SplitIoClient::Api::RequestDecorator::FORBIDDEN_HEADERS
        headers[header] = ["val"]
      end
      headers
  end
end

class MyCustomDecorator
  def get_header_overrides(request_context)
      headers = request_context.headers
      headers["UserCustomHeader"] = ["value"]
      headers["AnotherCustomHeader"] = ["val1", "val2"]
      headers
  end
end

describe SplitIoClient::Api::RequestDecorator do

  let(:api_client) do
    Faraday.new do |builder|
      builder.use SplitIoClient::FaradayMiddleware::Gzip
      builder.adapter :net_http_persistent
    end
  end
  let(:url) { 'https://example.org?hello=world' }
  let(:params) { { hello: :world } }

  before do
    stub_request(:get, url).to_return(status: 200)
  end

  context 'request decorator' do
    it 'no op mode' do
      request_decorator = described_class.new(nil)

      api_client.get(url, params) do |req|
        req.headers = {}
        req = request_decorator.decorate_headers(req)
        expect(req.headers).to eq({})
      end
    end

    it 'add custom headers' do
      request_decorator = described_class.new(MyCustomDecorator.new)

      api_client.get(url, params) do |req|
        req.headers = {}
        req = request_decorator.decorate_headers(req)
        expect(req.headers['UserCustomHeader']).to eq("value")
        expect(req.headers['AnotherCustomHeader']).to eq("val1, val2")
      end
    end

    it 'add forbidden headers' do
      request_decorator = described_class.new(MyCustomDecorator2.new)

      api_client.get(url, params) do |req|
        req.headers = {}
        req = request_decorator.decorate_headers(req)
        expect(req.headers['UserCustomHeader']).to eq("value")
        expect(req.headers.length).to eq(1)
      end
    end

    it 'handle errors' do
      request_decorator = described_class.new(MyCustomDecorator3.new)

      api_client.get(url, params) do |req|
        req.headers = {}
        expect { req = request_decorator.decorate_headers(req) }.to raise_error(
          'Problem adding custom header in request decorator'
        )
      end
    end
  end
end
