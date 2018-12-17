# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitFactory do
  before do
    SplitIoClient.configuration = nil
  end

  let(:log) { StringIO.new }
  let(:options) do
    {
      logger: Logger.new(log),
      cache_adapter: cache_adapter,
      mode: mode
    }
  end

  context 'when standalone is used with redis adapter' do
    let(:cache_adapter) { :redis }
    let(:mode) { :standalone }

    it 'raises an exception stating unsupported mode' do
      expect { described_class.new('API_KEY', options) }.to raise_error('Invalid SDK mode')
      expect(log.string).to include 'Standalone mode cannot be used with Redis adapter. Use Memory adapter instead.'
    end
  end

  context 'when consumer is used with memory adapter' do
    let(:cache_adapter) { :memory }
    let(:mode) { :consumer }

    it 'raises an exception stating unsupported mode' do
      expect { described_class.new('API_KEY', options) }.to raise_error('Invalid SDK mode')
      expect(log.string).to include 'Consumer mode cannot be used with Memory adapter. Use Redis adapter instead.'
    end
  end

  context 'when producer mode is used' do
    let(:mode) { :producer }
    let(:cache_adapter) { :memory }

    it 'raises an exception stating unsupported mode' do
      expect { described_class.new('API_KEY', options) }.to raise_error('Invalid SDK mode')
      expect(log.string).to include 'Producer mode is no longer supported. Use Split Synchronizer'
    end
  end

  context 'when mode is not standalone or consumer' do
    let(:mode) { :foo }
    let(:cache_adapter) { :memory }

    it 'raises an exception stating unsupported mode' do
      expect { described_class.new('API_KEY', options) }.to raise_error('Invalid SDK mode')
      expect(log.string).to include 'Invalid SDK mode selected.'
    end
  end
end
