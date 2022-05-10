# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Client do
  describe '#get_api' do
    it 'makes GET request without error' do
      url     = 'https://example.org?hello=world'
      api_key = 'abc-def-ghi'
      params  = { hello: :world }

      stub_request(:get, url).to_return(status: 200)

      expect { described_class.new(@default_config).get_api(url, api_key, params) }.not_to raise_error
    end

    it 'makes POST request without error' do
      url     = 'https://example.org'
      api_key = 'abc-def-ghi'
      data    = { hello: :world }

      stub_request(:post, url).to_return(status: 200)

      expect { described_class.new(@default_config).post_api(url, api_key, data) }.not_to raise_error
    end
  end
end
