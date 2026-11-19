# frozen_string_literal: true

require 'spec_helper'

# These specs stub Redis.new, so they do not need a running Redis server.
describe SplitIoClient::Cache::Adapters::RedisAdapter do
  let(:url) { 'redis://127.0.0.1:6379/0' }

  before do
    allow(Redis).to receive(:new).and_return(double('redis'))
  end

  context 'when redis-rb is 6 or newer' do
    before { stub_const('Redis::VERSION', '6.0.0') }

    it 'selects RESP2 for a string url' do
      described_class.new(url)

      expect(Redis).to have_received(:new).with(url: url, protocol: 2)
    end

    it 'selects RESP2 for a hash without a protocol and keeps the other options' do
      described_class.new(url: url, ssl: true)

      expect(Redis).to have_received(:new).with(url: url, ssl: true, protocol: 2)
    end

    it 'keeps the protocol chosen by the user' do
      described_class.new(url: url, protocol: 3)

      expect(Redis).to have_received(:new).with(url: url, protocol: 3)
    end

    it 'does not modify the hash passed by the caller' do
      options = { url: url }

      described_class.new(options)

      expect(options).to eq(url: url)
    end
  end

  context 'when redis-rb is older than 6' do
    %w[4.8.1 5.4.1].each do |version|
      it "does not add a protocol option on #{version}" do
        stub_const('Redis::VERSION', version)

        described_class.new(url)
        described_class.new(url: url)

        expect(Redis).to have_received(:new).with(url: url).twice
      end
    end
  end
end
