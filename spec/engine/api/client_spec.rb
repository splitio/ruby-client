# frozen_string_literal: true

require 'spec_helper'

class MyCustomDecorator
  def get_header_overrides(request_context)
      headers = request_context.headers
      headers["UserCustomHeader"] = ["value"]
      headers["AnotherCustomHeader"] = ["val1", "val2"]
      headers
  end
end

$headers = {}

class MyRequestDecorator < SplitIoClient::Api::RequestDecorator
  def initialize(custom_header_decorator)
  end

  def decorate_headers(headers)
    $headers = headers
    headers
  end
end

describe SplitIoClient::Api::Client do
  describe '#api' do
    it 'makes GET request without error' do
      url     = 'https://example.org?hello=world'
      api_key = 'abc-def-ghi'
      params  = { hello: :world }

      stub_request(:get, url).to_return(status: 200)

      expect { described_class.new(@default_config, SplitIoClient::Api::RequestDecorator.new(nil)).get_api(url, api_key, params) }.not_to raise_error
    end

    it 'makes POST request without error' do
      url     = 'https://example.org'
      api_key = 'abc-def-ghi'
      data    = { hello: :world }

      stub_request(:post, url).to_return(status: 200)

      expect { described_class.new(@default_config, SplitIoClient::Api::RequestDecorator.new(nil)).post_api(url, api_key, data) }.not_to raise_error
    end

    it 'verify calling request decorator' do
      url     = 'https://example.org?hello=world'
      api_key = 'abc-def-ghi'
      params  = { hello: :world }

      stub_request(:get, url).to_return(status: 200)

      client = described_class.new(@default_config, MyRequestDecorator.new(nil))
      client.get_api(url, api_key, params)

      expect($headers).to eq({"Accept-Encoding"=>"gzip", "Authorization" => "Bearer abc-def-ghi", "SplitSDKVersion" => "ruby-8.3.1"})
    end

  end
end
