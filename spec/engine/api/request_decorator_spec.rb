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
  context 'request decorator' do
    it 'no op mode' do
      request_decorator = described_class.new(nil)

      headers = {}
      headers = request_decorator.decorate_headers(headers)
      expect(headers).to eq({})
    end

    it 'add custom headers' do
      request_decorator = described_class.new(MyCustomDecorator.new)

      headers = {}
      headers = request_decorator.decorate_headers(headers)
      expect(headers['UserCustomHeader']).to eq("value")
      expect(headers['AnotherCustomHeader']).to eq("val1,val2")
    end

    it 'add forbidden headers' do
      request_decorator = described_class.new(MyCustomDecorator2.new)

      headers = {}
      headers = request_decorator.decorate_headers(headers)
      expect(headers['UserCustomHeader']).to eq("value")
      expect(headers.length).to eq(1)
    end

    it 'handle errors' do
      request_decorator = described_class.new(MyCustomDecorator3.new)

      headers = {}
      expect { headers = request_decorator.decorate_headers(headers) }.to raise_error(
          'Problem adding custom header in request decorator'
        )
    end
  end
end
