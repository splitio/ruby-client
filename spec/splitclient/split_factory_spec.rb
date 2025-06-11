# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::SplitFactory do
  let(:log) { StringIO.new }
  let(:options) do
    {
      logger: Logger.new(log),
      cache_adapter: cache_adapter,
      mode: mode,
      streaming_enabled: false
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

  context 'when consumer is used with localhost mode' do
    let(:cache_adapter) { :redis }
    let(:mode) { :consumer }

    it 'raises an exception stating unsupported mode' do
      expect { described_class.new('localhost', options) }.to raise_error('Invalid SDK mode')
      expect(log.string).to include 'Localhost mode cannot be used with Redis. ' \
        'Use standalone mode and Memory adapter instead.'
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

  context 'when api_key is null' do
    let(:cache_adapter) { :memory }
    let(:mode) { :standalone }

    it 'log an error stating Api Key is invalid' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      factory = described_class.new(nil, options)

      expect(log.string).to include 'Factory Instantiation: you passed a nil' \
        ' api_key, api_key must be a non-empty String'
      expect(factory.instance_variable_get(:@config).valid_mode).to be false
      expect(factory.client.get_treatment('test_user', 'test_feature'))
        .to eq SplitIoClient::Engine::Models::Treatment::CONTROL
    end
  end

  context 'when api_key is empty' do
    let(:cache_adapter) { :memory }
    let(:mode) { :standalone }

    it 'log an error stating Api Key is invalid' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      factory = described_class.new('', options)

      expect(log.string).to include 'Factory Instantiation: you passed and empty api_key,' \
        ' api_key must be a non-empty String'
      expect(factory.instance_variable_get(:@config).valid_mode).to be false
      expect(factory.client.track('key', 'traffic_type', 'event_type', 123))
        .to be false
    end
  end

  context 'when api_key is browser' do
    let(:cache_adapter) { :memory }
    let(:mode) { :standalone }
    let(:splits_with_segments_json) do
      File.read(File.expand_path(File.join(File.dirname(__FILE__), '../test_data/splits/splits3.json')))
    end

    it 'log an error stating Api Key is invalid' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: splits_with_segments_json)
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=1473863097220&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:get, 'https://sdk.split.io/api/segmentChanges/employees?since=-1')
        .to_return(status: 403, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      factory = described_class.new('browser_key', options)

      sleep 1
      expect(log.string).to include 'Factory Instantiation: You passed a browser type api_key,' \
        ' please grab an api key from the Split console that is of type sdk'
      expect(factory.instance_variable_get(:@config).valid_mode).to be false
      expect(factory.manager.split('test_split'))
        .to be nil

      puts '###### log'
      puts log.string
    end
  end

  context 'when client is destroyed' do
    let(:cache_adapter) { :memory }
    let(:mode) { :standalone }

    it 'log an error' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: 'ok')

      factory = described_class.new('browser_key', options)
      factory.client.destroy
      factory.client.get_treatment('key', 'split')
      expect(log.string).to include 'Client has already been destroyed - no calls possible'
      expect(factory.instance_variable_get(:@config).valid_mode).to be false
      expect(factory.manager.split('test_split'))
        .to be nil
    end
  end

  context 'when multiple factories' do
    let(:cache_adapter) { :memory }
    let(:mode) { :standalone }

    before :each do
      SplitIoClient.split_factory_registry = SplitIoClient::SplitFactoryRegistry.new

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: 'ok')
    end

    it 'logs warnings stating number of factories' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])

      described_class.new('API_KEY', options)
      described_class.new('API_KEY', options)

      expect(log.string).to include 'You already have 1 factories with this API Key'

      described_class.new('ANOTHER_API_KEY', options)

      expect(log.string).to include 'You already have an instance of the Split factory.'
    end

    it 'decreases number of registered factories on client destroy' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])

      expect(SplitIoClient.split_factory_registry.number_of_factories_for('API_KEY')).to eq 0

      factory = described_class.new('API_KEY', options)

      expect(SplitIoClient.split_factory_registry.number_of_factories_for('API_KEY')).to eq 1

      factory.client.destroy

      expect(SplitIoClient.split_factory_registry.number_of_factories_for('API_KEY')).to eq 0
    end

    it 'active and redundant factories' do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      described_class.new('API_KEY', options)

      described_class.new('ANOTHER_API_KEY', options)
      described_class.new('ANOTHER_API_KEY', options)

      described_class.new('ANOTHER_API_KEY-2', options)
      described_class.new('ANOTHER_API_KEY-2', options)
      described_class.new('ANOTHER_API_KEY-2', options)

      described_class.new('API_KEY-2', options)
      described_class.new('API_KEY-2', options)
      described_class.new('API_KEY-2', options)
      described_class.new('API_KEY-2', options)

      expect(SplitIoClient.split_factory_registry.active_factories).to be(4)
      expect(SplitIoClient.split_factory_registry.redundant_active_factories).to be(6)
    end
  end

  context 'when using flagsets' do
    let(:cache_adapter) { :memory }
    let(:mode) { :standalone }

    it 'no flagsets used' do
      factory = described_class.new('apikey', options)

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      tel_sync = factory.instance_variable_get(:@telemetry_synchronizer)
      tel_mem_sync = tel_sync.instance_variable_get(:@synchronizer)

      expect(tel_mem_sync.instance_variable_get(:@flag_sets)).to eq(0)
      expect(tel_mem_sync.instance_variable_get(:@flag_sets_invalid)).to eq(0)

      factory.client.destroy
    end

    it 'no invalid flagsets used' do
      factory = described_class.new('apikey', options.merge({:flag_sets_filter => ['set1', 'set2']}))

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      tel_sync = factory.instance_variable_get(:@telemetry_synchronizer)
      tel_mem_sync = tel_sync.instance_variable_get(:@synchronizer)

      expect(tel_mem_sync.instance_variable_get(:@flag_sets)).to eq(2)
      expect(tel_mem_sync.instance_variable_get(:@flag_sets_invalid)).to eq(0)

      factory.client.destroy
    end

    it 'have invalid flagsets used' do
      factory = described_class.new('apikey', options.merge({:flag_sets_filter => ['set1', 'se$t2', 'set3', 123, nil, '@@']}))

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      tel_sync = factory.instance_variable_get(:@telemetry_synchronizer)
      tel_mem_sync = tel_sync.instance_variable_get(:@synchronizer)

      expect(tel_mem_sync.instance_variable_get(:@flag_sets)).to eq(6)
      expect(tel_mem_sync.instance_variable_get(:@flag_sets_invalid)).to eq(4)

      factory.client.destroy
    end

    it 'have invalid value for param flagsets used' do
      factory = described_class.new('apikey', options.merge({:flag_sets_filter => 'set1'}))

      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: 'ok')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.3&since=-1&rbSince=-1')
        .to_return(status: 200, body: [])
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
        .to_return(status: 200, body: '')

      tel_sync = factory.instance_variable_get(:@telemetry_synchronizer)
      tel_mem_sync = tel_sync.instance_variable_get(:@synchronizer)

      expect(tel_mem_sync.instance_variable_get(:@flag_sets)).to eq(0)
      expect(tel_mem_sync.instance_variable_get(:@flag_sets_invalid)).to eq(0)

      factory.client.destroy
    end
  end
end
