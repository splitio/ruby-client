# frozen_string_literal: true

require 'spec_helper'
require 'my_impression_listener'

describe SplitIoClient do
  SINGLETON_WARN = 'We recommend keeping only one instance of the factory at all times ' \
    '(Singleton pattern) and reusing it throughout your application'

  let(:factory) do
    SplitIoClient::SplitFactory.new('test_api_key', impression_listener: custom_impression_listener, streaming_enabled: false)
  end

  let(:log) { StringIO.new }

  let(:splits) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/splits.json'))
  end

  let(:segment1) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment1.json'))
  end

  let(:segment2) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment2.json'))
  end

  let(:segment3) do
    File.read(File.join(SplitIoClient.root, 'spec/test_data/integrations/segment3.json'))
  end

  let(:client) { factory.client }
  let(:config) { client.instance_variable_get(:@config) }
  let(:custom_impression_listener) { MyImpressionListener.new }

  before do
    mock_split_changes(splits)
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')
    stub_request(:any, /https:\/\/events.*/).to_return(status: 200, body: '')
    stub_request(:any, /https:\/\/telemetry.*/).to_return(status: 200, body: 'ok')
#    sleep 1
  end

  #  after(:each) do
  #  client.destroy
   # sleep 0.5
  #end

  context '#get_treatment' do
    it 'returns CONTROL when server return 500' do
    #  stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      mock_split_changes_error
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'control'

      sleep 0.5
      impressions = custom_impression_listener.queue
      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('control')
      expect(impressions[0][:treatment][:label]).to eq('not ready')
      expect(impressions[0][:treatment][:change_number]).to eq(nil)
    end

    it 'returns treatments with FACUNDO_TEST feature and check impressions' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('mauro_test', 'FACUNDO_TEST')).to eq 'off'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('mauro_test')
      expect(impressions[1][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns treatments with Test_Save_1 feature and check impressions' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      expect(client.get_treatment('1', 'Test_Save_1')).to eq 'on'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2

      expect(impressions[0][:matching_key]).to eq('1')
      expect(impressions[0][:split_name]).to eq('Test_Save_1')
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_503_956_389_520)

      expect(impressions[1][:matching_key]).to eq('24')
      expect(impressions[1][:split_name]).to eq('Test_Save_1')
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_503_956_389_520)
    end

    it 'returns treatments with input validations' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('', 'FACUNDO_TEST')).to eq 'control'
      expect(client.get_treatment(nil, 'FACUNDO_TEST')).to eq 'control'
      expect(client.get_treatment('1', '')).to eq 'control'
      expect(client.get_treatment('1', nil)).to eq 'control'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('24')
      expect(impressions[1][:split_name]).to eq('Test_Save_1')
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_503_956_389_520)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      expect(client.get_treatment('nico_test', 'random_treatment')).to eq 'control'

      impressions = custom_impression_listener.queue
      expect(impressions.size).to eq 0
    end

    it 'with multiple factories returns on' do
#      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      local_log = StringIO.new
      logger = Logger.new(local_log)

      expect(logger).to receive(:warn)
        .with('Factory instantiation: You already have an instance of the Split factory.' \
          " Make sure you definitely want this additional instance. #{SINGLETON_WARN}")
        .exactly(3).times
      expect(logger).to receive(:warn)
        .with("Factory instantiation: You already have 1 factories with this API Key. #{SINGLETON_WARN}")
        .once

      impression_listener1 = MyImpressionListener.new
      impression_listener2 = MyImpressionListener.new
      impression_listener3 = MyImpressionListener.new
      impression_listener4 = MyImpressionListener.new
      factory1 = SplitIoClient::SplitFactory.new('api_key',
                                                 logger: logger,
                                                 impression_listener: impression_listener1,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                            streaming_enabled: false)
      factory2 = SplitIoClient::SplitFactory.new('another_key',
                                                 logger: logger,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                 impression_listener: impression_listener2,
                                                 streaming_enabled: false)
      factory3 = SplitIoClient::SplitFactory.new('random_key',
                                                 logger: logger,
                                                 impression_listener: impression_listener3,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                 streaming_enabled: false)
      factory4 = SplitIoClient::SplitFactory.new('api_key',
                                                 logger: logger,
                                                 impression_listener: impression_listener4,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                 streaming_enabled: false)

      client1 = factory1.client
      client2 = factory2.client
      client3 = factory3.client
      client4 = factory4.client

      client1.block_until_ready
      client2.block_until_ready
      client3.block_until_ready
      client4.block_until_ready

      expect(client1.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client2.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client3.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client4.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'

      sleep 0.5
      impressions1 = impression_listener1.queue
      impressions2 = impression_listener2.queue
      impressions3 = impression_listener3.queue
      impressions4 = impression_listener4.queue

      expect(impressions1.size).to eq 1
      expect(impressions2.size).to eq 1
      expect(impressions3.size).to eq 1
      expect(impressions4.size).to eq 1

      client1.destroy()
      client2.destroy()
      client3.destroy()
      client4.destroy()
    end
  end

  context '#get_treatment_with_config' do
    it 'returns treatments and configs with FACUNDO_TEST treatment and check impressions' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      expect(client.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(client.get_treatment_with_config('mauro_test', 'FACUNDO_TEST')).to eq(
        treatment: 'off',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('mauro_test')
      expect(impressions[1][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns treatments and configs with MAURO_TEST treatment and check impressions' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready

      expect(client.get_treatment_with_config('mauro', 'MAURO_TEST')).to eq(
        treatment: 'on',
        config: '{"version":"v2"}'
      )
      expect(client.get_treatment_with_config('test', 'MAURO_TEST')).to eq(
        treatment: 'off',
        config: '{"version":"v1"}'
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2

      expect(impressions[0][:matching_key]).to eq('mauro')
      expect(impressions[0][:split_name]).to eq('MAURO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_966)

      expect(impressions[1][:matching_key]).to eq('test')
      expect(impressions[1][:split_name]).to eq('MAURO_TEST')
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('not in split')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_703_262_966)
    end

    it 'returns treatments with input validations' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready

      expect(client.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(client.get_treatment_with_config('', 'FACUNDO_TEST')).to eq(
        treatment: 'control',
        config: nil
      )
      expect(client.get_treatment_with_config(nil, 'FACUNDO_TEST')).to eq(
        treatment: 'control',
        config: nil
      )
      expect(client.get_treatment_with_config('1', '')).to eq(
        treatment: 'control',
        config: nil
      )
      expect(client.get_treatment_with_config('1', nil)).to eq(
        treatment: 'control',
        config: nil
      )
      expect(client.get_treatment_with_config('24', 'Test_Save_1')).to eq(
        treatment: 'off',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('24')
      expect(impressions[1][:split_name]).to eq('Test_Save_1')
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_503_956_389_520)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready

      expect(client.get_treatment_with_config('nico_test', 'random_treatment')).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue
      expect(impressions.size).to eq 0
    end

    it 'returns CONTROL when server return 500' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      mock_split_changes_error

      expect(client.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq('FACUNDO_TEST')
      expect(impressions[0][:treatment][:treatment]).to eq('control')
      expect(impressions[0][:treatment][:label]).to eq('not ready')
      expect(impressions[0][:treatment][:change_number]).to eq(nil)
    end
  end

  context '#get_treatments' do
    before do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
    end

    it 'returns treatments and check impressions' do
      client.block_until_ready
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:MAURO_TEST]).to eq 'off'
      expect(result[:Test_Save_1]).to eq 'off'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:MAURO_TEST)
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('not in split')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_703_262_966)

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:Test_Save_1)
      expect(impressions[2][:treatment][:treatment]).to eq('off')
      expect(impressions[2][:treatment][:label]).to eq('in segment all')
      expect(impressions[2][:treatment][:change_number]).to eq(1_503_956_389_520)
    end

    it 'returns treatments with input validation' do
      client.block_until_ready
      result1 = client.get_treatments('nico_test', ['FACUNDO_TEST', '', nil])
      result2 = client.get_treatments('', ['', 'MAURO_TEST', 'Test_Save_1'])
      result3 = client.get_treatments(nil, ['', 'MAURO_TEST', 'Test_Save_1'])

      expect(result1[:FACUNDO_TEST]).to eq 'on'
      expect(result2[:MAURO_TEST]).to eq 'control'
      expect(result2[:Test_Save_1]).to eq 'control'
      expect(result3[:MAURO_TEST]).to eq 'control'
      expect(result3[:Test_Save_1]).to eq 'control'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      client.block_until_ready
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:random_treatment]).to eq 'control'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error
      sleep 1
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq 'control'
      expect(result[:random_treatment]).to eq 'control'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 2
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('control')
      expect(impressions[0][:treatment][:label]).to eq('not ready')
      expect(impressions[0][:treatment][:change_number]).to eq(nil)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:random_treatment)
      expect(impressions[1][:treatment][:treatment]).to eq('control')
      expect(impressions[1][:treatment][:label]).to eq('not ready')
      expect(impressions[1][:treatment][:change_number]).to eq(nil)
    end
  end

  context '#get_treatments_by_flag_set' do
    before do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
    end

    it 'returns treatments and check impressions' do
      client.block_until_ready
      result = client.get_treatments_by_flag_set('nico_test', 'set_3')
      expect(result[:FACUNDO_TEST]).to eq 'on'

      result = client.get_treatments_by_flag_set('nico_test', 'set_2')
      expect(result[:testing]).to eq 'off'
      expect(result[:testing222]).to eq 'off'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:testing)
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in split test_definition_as_of treatment [off]')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_440_189_077)

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:testing222)
      expect(impressions[2][:treatment][:treatment]).to eq('off')
      expect(impressions[2][:treatment][:label]).to eq('in segment all')
      expect(impressions[2][:treatment][:change_number]).to eq(1_505_162_627_437)
    end

    it 'returns treatments with input validation' do
      client.block_until_ready
      result1 = client.get_treatments_by_flag_set('nico_test', 'set_3 ')
      result2 = client.get_treatments_by_flag_set('', 'set_2')
      result3 = client.get_treatments_by_flag_set(nil, 'set_1')

      expect(result1[:FACUNDO_TEST]).to eq 'on'
      expect(result2[:testing]).to eq 'control'
      expect(result2[:testing222]).to eq 'control'
      expect(result2[:testing222]).to eq 'control'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      client.block_until_ready
      result = client.get_treatments_by_flag_set('nico_test', 'invalid_set')
      expect(result).to eq({})
      result = client.get_treatments_by_flag_set('nico_test', 'set_3')

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      result = client.get_treatments_by_flag_set('nico_test', 'set_2')
      expect(result).to eq({})
    end
  end

  context '#get_treatments_by_flag_sets' do
    before do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
    end

    it 'returns treatments and check impressions' do
      client.block_until_ready
      result = client.get_treatments_by_flag_sets('nico_test', ['set_3', 'set_2'])
      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:testing]).to eq 'off'
      expect(result[:testing222]).to eq 'off'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[2][:treatment][:treatment]).to eq('on')
      expect(impressions[2][:treatment][:label]).to eq('whitelisted')
      expect(impressions[2][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:testing)
      expect(impressions[0][:treatment][:treatment]).to eq('off')
      expect(impressions[0][:treatment][:label]).to eq('in split test_definition_as_of treatment [off]')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_440_189_077)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:testing222)
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_505_162_627_437)
    end

    it 'returns treatments with input validation' do
      client.block_until_ready
      result1 = client.get_treatments_by_flag_sets('nico_test', ['set_3 ', 'invalid', ''])
      result2 = client.get_treatments_by_flag_sets('', ['set_2', 123, 'se@t', '//s'])
      result3 = client.get_treatments_by_flag_sets(nil, ['set_1'])

      expect(result1[:FACUNDO_TEST]).to eq 'on'
      expect(result2[:testing]).to eq 'control'
      expect(result2[:testing222]).to eq 'control'
      expect(result2[:testing222]).to eq 'control'

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      client.block_until_ready
      result = client.get_treatments_by_flag_sets('nico_test', ['invalid_set'])
      expect(result).to eq({})
      result = client.get_treatments_by_flag_sets('nico_test', ['set_3'])

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      result = client.get_treatments_by_flag_sets('nico_test', ['set_2'])
      expect(result).to eq({})
    end
  end

  context '#get_treatments_with_config_by_flag_set' do
    before do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
    end

    it 'returns treatments and check impressions' do
      client.block_until_ready
      result = client.get_treatments_with_config_by_flag_set('nico_test', 'set_3')
      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )

      result = client.get_treatments_with_config_by_flag_set('nico_test', 'set_2')
      expect(result[:testing]).to eq(
        treatment: 'off',
        config: nil
      )
      expect(result[:testing222]).to eq(
        treatment: 'off',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:testing)
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in split test_definition_as_of treatment [off]')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_440_189_077)

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:testing222)
      expect(impressions[2][:treatment][:treatment]).to eq('off')
      expect(impressions[2][:treatment][:label]).to eq('in segment all')
      expect(impressions[2][:treatment][:change_number]).to eq(1_505_162_627_437)
    end

    it 'returns treatments with input validation' do
      client.block_until_ready
      result1 = client.get_treatments_with_config_by_flag_set('nico_test', 'set_3 ')
      result2 = client.get_treatments_with_config_by_flag_set('', 'set_2')
      result3 = client.get_treatments_with_config_by_flag_set(nil, 'set_1')

      expect(result1[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result2[:testing]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result2[:testing222]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result2[:testing222]).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      client.block_until_ready
      result = client.get_treatments_with_config_by_flag_set('nico_test', 'invalid_set')
      expect(result).to eq({})
      result = client.get_treatments_with_config_by_flag_set('nico_test', 'set_3')
      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      result = client.get_treatments_with_config_by_flag_set('nico_test', 'set_2')
      expect(result).to eq({})
    end
  end

  context '#get_treatments_with_config_by_flag_sets' do
    before do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
    end

    it 'returns treatments and check impressions' do
      client.block_until_ready
      result = client.get_treatments_with_config_by_flag_sets('nico_test', ['set_3', 'set_2'])
      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result[:testing]).to eq(
        treatment: 'off',
        config: nil
      )
      expect(result[:testing222]).to eq(
        treatment: 'off',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[2][:treatment][:treatment]).to eq('on')
      expect(impressions[2][:treatment][:label]).to eq('whitelisted')
      expect(impressions[2][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:testing)
      expect(impressions[0][:treatment][:treatment]).to eq('off')
      expect(impressions[0][:treatment][:label]).to eq('in split test_definition_as_of treatment [off]')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_440_189_077)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:testing222)
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('in segment all')
      expect(impressions[1][:treatment][:change_number]).to eq(1_505_162_627_437)
    end

    it 'returns treatments with input validation' do
      client.block_until_ready
      result1 = client.get_treatments_with_config_by_flag_sets('nico_test', ['set_3 ', 'invalid', ''])
      result2 = client.get_treatments_with_config_by_flag_sets('', ['set_2', 123, 'se@t', '//s'])
      result3 = client.get_treatments_with_config_by_flag_sets(nil, ['set_1'])

      expect(result1[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result2[:testing]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result2[:testing222]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result2[:testing222]).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      client.block_until_ready
      result = client.get_treatments_with_config_by_flag_sets('nico_test', ['invalid_set'])
      expect(result).to eq({})
      result = client.get_treatments_with_config_by_flag_sets('nico_test', ['set_3'])

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      result = client.get_treatments_with_config_by_flag_sets('nico_test', ['set_2'])
      expect(result).to eq({})
    end
  end

  context '#get_treatments_with_config' do
    it 'returns treatments and check impressions' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      result = client.get_treatments_with_config('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result[:MAURO_TEST]).to eq(
        treatment: 'off',
        config: '{"version":"v1"}'
      )
      expect(result[:Test_Save_1]).to eq(
        treatment: 'off',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:MAURO_TEST)
      expect(impressions[1][:treatment][:treatment]).to eq('off')
      expect(impressions[1][:treatment][:label]).to eq('not in split')
      expect(impressions[1][:treatment][:change_number]).to eq(1_506_703_262_966)

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:Test_Save_1)
      expect(impressions[2][:treatment][:treatment]).to eq('off')
      expect(impressions[2][:treatment][:label]).to eq('in segment all')
      expect(impressions[2][:treatment][:change_number]).to eq(1_503_956_389_520)
    end

    it 'returns treatments with input validation' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      result1 = client.get_treatments_with_config('nico_test', %w[FACUNDO_TEST "" nil])
      result2 = client.get_treatments_with_config('', %w["" MAURO_TEST Test_Save_1])
      result3 = client.get_treatments_with_config(nil, %w["" MAURO_TEST Test_Save_1])

      expect(result1[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result2[:MAURO_TEST]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result2[:Test_Save_1]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result3[:MAURO_TEST]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result3[:Test_Save_1]).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      client.block_until_ready
      result = client.get_treatments_with_config('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result[:random_treatment]).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 1
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('on')
      expect(impressions[0][:treatment][:label]).to eq('whitelisted')
      expect(impressions[0][:treatment][:change_number]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      stub_request(:get, "https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916").to_return(status: 200, body: 'ok')
      mock_split_changes_error

      result = client.get_treatments_with_config('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])
      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result[:MAURO_TEST]).to eq(
        treatment: 'control',
        config: nil
      )
      expect(result[:Test_Save_1]).to eq(
        treatment: 'control',
        config: nil
      )

      sleep 0.5
      impressions = custom_impression_listener.queue

      expect(impressions.size).to eq 3
      expect(impressions[0][:matching_key]).to eq('nico_test')
      expect(impressions[0][:split_name]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:treatment][:treatment]).to eq('control')
      expect(impressions[0][:treatment][:label]).to eq('not ready')
      expect(impressions[0][:treatment][:change_number]).to eq(nil)

      expect(impressions[1][:matching_key]).to eq('nico_test')
      expect(impressions[1][:split_name]).to eq(:MAURO_TEST)
      expect(impressions[1][:treatment][:treatment]).to eq('control')
      expect(impressions[1][:treatment][:label]).to eq('not ready')
      expect(impressions[1][:treatment][:change_number]).to eq(nil)

      expect(impressions[2][:matching_key]).to eq('nico_test')
      expect(impressions[2][:split_name]).to eq(:Test_Save_1)
      expect(impressions[2][:treatment][:treatment]).to eq('control')
      expect(impressions[2][:treatment][:label]).to eq('not ready')
      expect(impressions[2][:treatment][:change_number]).to eq(nil)
    end

    it 'with multiple factories returns on' do
      local_log = StringIO.new
      logger = Logger.new(local_log)

      expect(logger).to receive(:warn)
        .with('Factory instantiation: You already have an instance of the Split factory.' \
          " Make sure you definitely want this additional instance. #{SINGLETON_WARN}")
        .twice
      expect(logger).to receive(:warn)
        .with("Factory instantiation: You already have 1 factories with this API Key. #{SINGLETON_WARN}")
        .once

      impression_listener1 = MyImpressionListener.new
      impression_listener2 = MyImpressionListener.new
      impression_listener3 = MyImpressionListener.new
      factory1 = SplitIoClient::SplitFactory.new('api_key_other',
                                                 logger: logger,
                                                 impression_listener: impression_listener1,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                 streaming_enabled: false)
      factory2 = SplitIoClient::SplitFactory.new('another_key_second',
                                                 logger: logger,
                                                 impression_listener: impression_listener2,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                 streaming_enabled: false)
      factory3 = SplitIoClient::SplitFactory.new('api_key_other',
                                                 logger: logger,
                                                 impression_listener: impression_listener3,
                                                 features_refresh_rate: 9999,
                                                 telemetry_refresh_rate: 99999,
                                                 impressions_refresh_rate: 99999,
                                                 streaming_enabled: false)

      client1 = factory1.client
      client2 = factory2.client
      client3 = factory3.client

      client1.block_until_ready
      client2.block_until_ready
      client3.block_until_ready

      result1 = client1.get_treatments_with_config('nico_test', %w[MAURO_TEST])
      result2 = client2.get_treatments_with_config('nico_test', %w[MAURO_TEST])
      result3 = client3.get_treatments_with_config('nico_test', %w[FACUNDO_TEST])

      expect(result1[:MAURO_TEST]).to eq(
        treatment: 'off',
        config: '{"version":"v1"}'
      )
      expect(result2[:MAURO_TEST]).to eq(
        treatment: 'off',
        config: '{"version":"v1"}'
      )
      expect(result3[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )

      sleep 0.5
      impressions1 = impression_listener1.queue
      impressions2 = impression_listener2.queue
      impressions3 = impression_listener3.queue

      expect(impressions1.size).to eq 1
      expect(impressions2.size).to eq 1
      expect(impressions3.size).to eq 1

      client1.destroy()
      client2.destroy()
      client3.destroy()
    end
  end

  context '#track' do
    it 'returns true' do
      stub_request(:post, 'https://events.split.io/api/events/bulk').to_return(status: 200, body: '')
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=1506703262916').to_return(status: 200, body: '')

      properties = {
        property_1: 1,
        property_2: 2
      }

      client.block_until_ready
      sleep 1

      expect(client.track('key_1', 'traffic_type_1', 'event_type_1', 123, properties)).to be_truthy
      expect(client.track('key_2', 'traffic_type_2', 'event_type_2', 125)).to be_truthy

      events = client.instance_variable_get(:@events_repository).batch

      expect(events.size).to eq 2

      expect(events[0][:e][:key]).to eq('key_1')
      expect(events[0][:e][:trafficTypeName]).to eq('traffic_type_1')
      expect(events[0][:e][:eventTypeId]).to eq('event_type_1')
      expect(events[0][:e][:value]).to eq(123)
      expect(events[0][:e][:properties][:property_1]).to eq(1)
      expect(events[0][:e][:properties][:property_2]).to eq(2)

      expect(events[1][:e][:key]).to eq('key_2')
      expect(events[1][:e][:trafficTypeName]).to eq('traffic_type_2')
      expect(events[1][:e][:eventTypeId]).to eq('event_type_2')
      expect(events[1][:e][:value]).to eq(125)
      expect(events[1][:e][:properties].nil?).to be_truthy
    end

    it 'returns false with invalid data' do
      properties = {
        property_1: 1,
        property_2: 2
      }
      expect(client.track('', 'traffic_type_1', 'event_type_1', 123, properties)).to be_falsey
      expect(client.track('key_2', nil, 'event_type_2', 125)).to be_falsey
      expect(client.track('key_3', 'traffic_type_3', '', 125)).to be_falsey
      expect(client.track('key_4', 'traffic_type_4', 'event_type_4', '')).to be_falsey
      expect(client.track('key_5', 'traffic_type_5', 'event_type_5', 555, '')).to be_falsey

      events = client.instance_variable_get(:@events_repository).batch

      expect(events.size).to eq 0
      client.destroy()
    end
  end

  context 'using flag set filter' do
    let(:factory1) do
      SplitIoClient::SplitFactory.new('test_api_key',
        features_refresh_rate: 9999,
        telemetry_refresh_rate: 99999,
        impressions_refresh_rate: 99999,
        streaming_enabled: false,
        flag_sets_filter: ['set_3', '@3we'])
    end
      before do
      stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1&sets=set_3')
      .to_return(status: 200, body: splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')

    end

    it 'test get_treatments_by_flag_set' do
      client1 = factory1.client
      client1.block_until_ready
      result = client1.get_treatments_by_flag_set('nico_test', 'set_3')
      expect(result[:FACUNDO_TEST]).to eq 'on'

      result = client1.get_treatments_by_flag_set('nico_test', 'set_2')
      expect(result).to eq({})
    end

    it 'test get_treatments_by_flag_sets' do
      client1 = factory1.client
      client1.block_until_ready
      result = client1.get_treatments_by_flag_sets('nico_test', ['set_3'])
      expect(result[:FACUNDO_TEST]).to eq 'on'

      result = client1.get_treatments_by_flag_sets('nico_test', ['set_2', 'set_1'])
      expect(result).to eq({})

      result = client1.get_treatments_by_flag_sets('nico_test', ['set_2', 'set_3'])
      expect(result[:FACUNDO_TEST]).to eq 'on'
    end

    it 'test get_treatments_with_config_by_flag_set' do
      client1 = factory1.client
      client1.block_until_ready
      result = client1.get_treatments_with_config_by_flag_set('nico_test', 'set_3')
      expect(result[:FACUNDO_TEST]).to eq({:config=>"{\"color\":\"green\"}", :treatment=>"on"})

      result = client1.get_treatments_with_config_by_flag_set('nico_test', 'set_2')
      expect(result).to eq({})
    end

    it 'test get_treatments_with_config_by_flag_sets' do
      client1 = factory1.client
      client1.block_until_ready
      result = client1.get_treatments_with_config_by_flag_sets('nico_test', ['set_3'])
      expect(result[:FACUNDO_TEST]).to eq({:config=>"{\"color\":\"green\"}", :treatment=>"on"})

      result = client1.get_treatments_with_config_by_flag_sets('nico_test', ['set_2', 'set_1'])
      expect(result).to eq({})

      result = client1.get_treatments_with_config_by_flag_sets('nico_test', ['set_2', 'set_3'])
      expect(result[:FACUNDO_TEST]).to eq({:config=>"{\"color\":\"green\"}", :treatment=>"on"})
    end

  end
end

private

def mock_split_changes(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')
    .to_return(status: 200, body: splits_json)
end

def mock_split_changes_error
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?s=1.1&since=-1')
    .to_return(status: 500)
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
