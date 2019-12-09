# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  SINGLETON_WARN = 'We recommend keeping only one instance of the factory at all times ' \
    '(Singleton pattern) and reusing it throughout your application'

  let(:factory) do
    SplitIoClient::SplitFactory.new('test_api_key')
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

  before do
    mock_split_changes(splits)
    mock_segment_changes('segment1', segment1, '-1')
    mock_segment_changes('segment1', segment1, '1470947453877')
    mock_segment_changes('segment2', segment2, '-1')
    mock_segment_changes('segment2', segment2, '1470947453878')
    mock_segment_changes('segment3', segment3, '-1')
    mock_segment_changes('segment3', segment3, '1470947453879')
  end

  context '#get_treatment' do
    it 'returns treatments with FACUNDO_TEST feature and check impressions' do
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('mauro_test', 'FACUNDO_TEST')).to eq 'off'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('mauro_test')
      expect(impressions[1][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('in segment all')
      expect(impressions[1][:i][:c]).to eq(1_506_703_262_916)
    end

    it 'returns treatments with Test_Save_1 feature and check impressions' do
      expect(client.get_treatment('1', 'Test_Save_1')).to eq 'on'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('1')
      expect(impressions[0][:i][:f]).to eq('Test_Save_1')
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_503_956_389_520)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('24')
      expect(impressions[1][:i][:f]).to eq('Test_Save_1')
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('in segment all')
      expect(impressions[1][:i][:c]).to eq(1_503_956_389_520)
    end

    it 'returns treatments with input validations' do
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('', 'FACUNDO_TEST')).to eq 'control'
      expect(client.get_treatment(nil, 'FACUNDO_TEST')).to eq 'control'
      expect(client.get_treatment('1', '')).to eq 'control'
      expect(client.get_treatment('1', nil)).to eq 'control'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('24')
      expect(impressions[1][:i][:f]).to eq('Test_Save_1')
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('in segment all')
      expect(impressions[1][:i][:c]).to eq(1_503_956_389_520)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      expect(client.get_treatment('nico_test', 'random_treatment')).to eq 'control'

      impressions = client.instance_variable_get(:@impressions_repository).batch
      expect(impressions.size).to eq 0
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'control'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 1
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[0][:i][:t]).to eq('control')
      expect(impressions[0][:i][:r]).to eq('not ready')
      expect(impressions[0][:i][:c]).to eq(nil)
    end

    it 'with multiple factories returns on' do
      local_log = StringIO.new
      logger = Logger.new(local_log)

      expect(logger).to receive(:warn)
        .with('Factory instantiation: You already have an instance of the Split factory.' \
          " Make sure you definitely want this additional instance. #{SINGLETON_WARN}")
        .exactly(3).times
      expect(logger).to receive(:warn)
        .with("Factory instantiation: You already have 1 factories with this API Key. #{SINGLETON_WARN}")
        .once

      factory1 = SplitIoClient::SplitFactory.new('api_key', logger: logger)
      factory2 = SplitIoClient::SplitFactory.new('another_key', logger: logger)
      factory3 = SplitIoClient::SplitFactory.new('random_key', logger: logger)
      factory4 = SplitIoClient::SplitFactory.new('api_key', logger: logger)

      client1 = factory1.client
      client2 = factory2.client
      client3 = factory3.client
      client4 = factory4.client

      expect(client1.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client2.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client3.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client4.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'

      impressions1 = client1.instance_variable_get(:@impressions_repository).batch
      impressions2 = client2.instance_variable_get(:@impressions_repository).batch
      impressions3 = client3.instance_variable_get(:@impressions_repository).batch
      impressions4 = client4.instance_variable_get(:@impressions_repository).batch

      expect(impressions1.size).to eq 1
      expect(impressions2.size).to eq 1
      expect(impressions3.size).to eq 1
      expect(impressions4.size).to eq 1
    end
  end

  context '#get_treatment_with_config' do
    it 'returns treatments and configs with FACUNDO_TEST treatment and check impressions' do
      expect(client.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(client.get_treatment_with_config('mauro_test', 'FACUNDO_TEST')).to eq(
        treatment: 'off',
        config: nil
      )

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('mauro_test')
      expect(impressions[1][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('in segment all')
      expect(impressions[1][:i][:c]).to eq(1_506_703_262_916)
    end

    it 'returns treatments and configs with MAURO_TEST treatment and check impressions' do
      expect(client.get_treatment_with_config('mauro', 'MAURO_TEST')).to eq(
        treatment: 'on',
        config: '{"version":"v2"}'
      )
      expect(client.get_treatment_with_config('test', 'MAURO_TEST')).to eq(
        treatment: 'off',
        config: '{"version":"v1"}'
      )

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('mauro')
      expect(impressions[0][:i][:f]).to eq('MAURO_TEST')
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_966)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('test')
      expect(impressions[1][:i][:f]).to eq('MAURO_TEST')
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('not in split')
      expect(impressions[1][:i][:c]).to eq(1_506_703_262_966)
    end

    it 'returns treatments with input validations' do
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

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('24')
      expect(impressions[1][:i][:f]).to eq('Test_Save_1')
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('in segment all')
      expect(impressions[1][:i][:c]).to eq(1_503_956_389_520)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      expect(client.get_treatment_with_config('nico_test', 'random_treatment')).to eq(
        treatment: 'control',
        config: nil
      )

      impressions = client.instance_variable_get(:@impressions_repository).batch
      expect(impressions.size).to eq 0
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      expect(client.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'control',
        config: nil
      )

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 1
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq('FACUNDO_TEST')
      expect(impressions[0][:i][:t]).to eq('control')
      expect(impressions[0][:i][:r]).to eq('not ready')
      expect(impressions[0][:i][:c]).to eq(nil)
    end
  end

  context '#get_treatments' do
    it 'returns treatments and check impressions' do
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:MAURO_TEST]).to eq 'off'
      expect(result[:Test_Save_1]).to eq 'off'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3

      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('nico_test')
      expect(impressions[1][:i][:f]).to eq(:MAURO_TEST)
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('not in split')
      expect(impressions[1][:i][:c]).to eq(1_506_703_262_966)

      expect(impressions[2][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[2][:m][:i]).to eq(config.machine_ip)
      expect(impressions[2][:m][:n]).to eq(config.machine_name)
      expect(impressions[2][:i][:k]).to eq('nico_test')
      expect(impressions[2][:i][:f]).to eq(:Test_Save_1)
      expect(impressions[2][:i][:t]).to eq('off')
      expect(impressions[2][:i][:r]).to eq('in segment all')
      expect(impressions[2][:i][:c]).to eq(1_503_956_389_520)
    end

    it 'returns treatments with input validation' do
      result1 = client.get_treatments('nico_test', ['FACUNDO_TEST', '', nil])
      result2 = client.get_treatments('', ['', 'MAURO_TEST', 'Test_Save_1'])
      result3 = client.get_treatments(nil, ['', 'MAURO_TEST', 'Test_Save_1'])

      expect(result1[:FACUNDO_TEST]).to eq 'on'
      expect(result2[:MAURO_TEST]).to eq 'control'
      expect(result2[:Test_Save_1]).to eq 'control'
      expect(result3[:MAURO_TEST]).to eq 'control'
      expect(result3[:Test_Save_1]).to eq 'control'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 1
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:random_treatment]).to eq 'control'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 1
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
      mock_split_changes_error

      result = client.get_treatments('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq 'control'
      expect(result[:random_treatment]).to eq 'control'

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('control')
      expect(impressions[0][:i][:r]).to eq('not ready')
      expect(impressions[0][:i][:c]).to eq(nil)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('nico_test')
      expect(impressions[1][:i][:f]).to eq(:random_treatment)
      expect(impressions[1][:i][:t]).to eq('control')
      expect(impressions[1][:i][:r]).to eq('not ready')
      expect(impressions[1][:i][:c]).to eq(nil)
    end
  end

  context '#get_treatments_with_config' do
    it 'returns treatments and check impressions' do
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

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('nico_test')
      expect(impressions[1][:i][:f]).to eq(:MAURO_TEST)
      expect(impressions[1][:i][:t]).to eq('off')
      expect(impressions[1][:i][:r]).to eq('not in split')
      expect(impressions[1][:i][:c]).to eq(1_506_703_262_966)

      expect(impressions[2][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[2][:m][:i]).to eq(config.machine_ip)
      expect(impressions[2][:m][:n]).to eq(config.machine_name)
      expect(impressions[2][:i][:k]).to eq('nico_test')
      expect(impressions[2][:i][:f]).to eq(:Test_Save_1)
      expect(impressions[2][:i][:t]).to eq('off')
      expect(impressions[2][:i][:r]).to eq('in segment all')
      expect(impressions[2][:i][:c]).to eq(1_503_956_389_520)
    end

    it 'returns treatments with input validation' do
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

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 1
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      result = client.get_treatments_with_config('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result[:random_treatment]).to eq(
        treatment: 'control',
        config: nil
      )

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 1
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('on')
      expect(impressions[0][:i][:r]).to eq('whitelisted')
      expect(impressions[0][:i][:c]).to eq(1_506_703_262_916)
    end

    it 'returns CONTROL when server return 500' do
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

      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3
      expect(impressions[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[0][:m][:i]).to eq(config.machine_ip)
      expect(impressions[0][:m][:n]).to eq(config.machine_name)
      expect(impressions[0][:i][:k]).to eq('nico_test')
      expect(impressions[0][:i][:f]).to eq(:FACUNDO_TEST)
      expect(impressions[0][:i][:t]).to eq('control')
      expect(impressions[0][:i][:r]).to eq('not ready')
      expect(impressions[0][:i][:c]).to eq(nil)

      expect(impressions[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[1][:m][:i]).to eq(config.machine_ip)
      expect(impressions[1][:m][:n]).to eq(config.machine_name)
      expect(impressions[1][:i][:k]).to eq('nico_test')
      expect(impressions[1][:i][:f]).to eq(:MAURO_TEST)
      expect(impressions[1][:i][:t]).to eq('control')
      expect(impressions[1][:i][:r]).to eq('not ready')
      expect(impressions[1][:i][:c]).to eq(nil)

      expect(impressions[2][:m][:s]).to eq("ruby-#{config.version}")
      expect(impressions[2][:m][:i]).to eq(config.machine_ip)
      expect(impressions[2][:m][:n]).to eq(config.machine_name)
      expect(impressions[2][:i][:k]).to eq('nico_test')
      expect(impressions[2][:i][:f]).to eq(:Test_Save_1)
      expect(impressions[2][:i][:t]).to eq('control')
      expect(impressions[2][:i][:r]).to eq('not ready')
      expect(impressions[2][:i][:c]).to eq(nil)
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

      factory1 = SplitIoClient::SplitFactory.new('api_key_other', logger: logger)
      factory2 = SplitIoClient::SplitFactory.new('another_key_second', logger: logger)
      factory3 = SplitIoClient::SplitFactory.new('api_key_other', logger: logger)

      client1 = factory1.client
      client2 = factory2.client
      client3 = factory3.client

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

      impressions1 = client1.instance_variable_get(:@impressions_repository).batch
      impressions2 = client2.instance_variable_get(:@impressions_repository).batch
      impressions3 = client3.instance_variable_get(:@impressions_repository).batch

      expect(impressions1.size).to eq 1
      expect(impressions2.size).to eq 1
      expect(impressions3.size).to eq 1
    end
  end

  context '#track' do
    it 'returns true' do
      properties = {
        property_1: 1,
        property_2: 2
      }
      expect(client.track('key_1', 'traffic_type_1', 'event_type_1', 123, properties)).to be_truthy
      expect(client.track('key_2', 'traffic_type_2', 'event_type_2', 125)).to be_truthy

      events = client.instance_variable_get(:@events_repository).batch

      expect(events.size).to eq 2

      expect(events[0][:m][:s]).to eq("ruby-#{config.version}")
      expect(events[0][:m][:i]).to eq(config.machine_ip)
      expect(events[0][:m][:n]).to eq(config.machine_name)
      expect(events[0][:e][:key]).to eq('key_1')
      expect(events[0][:e][:trafficTypeName]).to eq('traffic_type_1')
      expect(events[0][:e][:eventTypeId]).to eq('event_type_1')
      expect(events[0][:e][:value]).to eq(123)
      expect(events[0][:e][:properties][:property_1]).to eq(1)
      expect(events[0][:e][:properties][:property_2]).to eq(2)

      expect(events[1][:m][:s]).to eq("ruby-#{config.version}")
      expect(events[1][:m][:i]).to eq(config.machine_ip)
      expect(events[1][:m][:n]).to eq(config.machine_name)
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
    end
  end
end

private

def mock_split_changes(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
    .to_return(status: 200, body: splits_json)
end

def mock_split_changes_error
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
    .to_return(status: 500)
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
