# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Api::Client do
  describe '#get_api' do
    it 'makes GET request without error' do
      url     = 'https://example.org?hello=world'
      api_key = 'abc-def-ghi'
      params  = { hello: :world }

      stub_request(:get, url).to_return(status: 200)

      expect { described_class.new.get_api(url, api_key, params) }.not_to raise_error
    end

    it 'makes POST request without error' do
      url     = 'https://example.org'
      api_key = 'abc-def-ghi'
      data    = { hello: :world }

      stub_request(:post, url).to_return(status: 200)

      expect { described_class.new.post_api(url, api_key, data) }.not_to raise_error
    end

    incompatible_faraday                = Faraday::VERSION.split('.')[0..1].reduce(0) { |sum, ver| sum += ver.to_i } < 13
    changed_net_http_persistent_version = Net::HTTP::Persistent::VERSION.split('.').first.to_i >= 3

    if incompatible_faraday && changed_net_http_persistent_version
      it 'uses PatchedNetHttpPersistent middleware' do
        url     = 'https://example.org?hello=world'
        api_key = 'abc-def-ghi'
        params  = { hello: :world }

        stub_request(:get, url).to_return(status: 200)

        expect_any_instance_of(SplitIoClient::FaradayAdapter::PatchedNetHttpPersistent)
          .to receive(:net_http_connection).and_call_original

        described_class.new.get_api(url, api_key, params)
      end
    end
  end
end
