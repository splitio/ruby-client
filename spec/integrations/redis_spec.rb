# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
  let(:factory) do
      SplitIoClient::SplitFactory.new('test_api_key',
                                      logger: Logger.new(log),
                                      cache_adapter: :redis,
                                      redis_namespace: 'test',
                                      mode: :consumer,
                                      redis_url: 'redis://127.0.0.1:6379/0')
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

  subject { factory.client }
  
  context '#get_treatment' do
    before do
      load_splits_redis(splits)
      load_segment_redis(segment1)
      load_segment_redis(segment2)
      load_segment_redis(segment3)
    end

    it 'returns treatments with FACUNDO_TEST feature and check impressions' do
      expect(subject.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(subject.get_treatment('mauro_test', 'FACUNDO_TEST')).to eq 'off'

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        'mauro_test',
        :FACUNDO_TEST,
        'off',
        'in segment all',
        1506703262916
      )
    end

    it 'returns treatments with Test_Save_1 feature and check impressions' do
      expect(subject.get_treatment('1', 'Test_Save_1')).to eq 'on'
      expect(subject.get_treatment('24', 'Test_Save_1')).to eq 'off'

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version, 
        config.machine_ip,
        config.machine_name,
        '1',
        :Test_Save_1,
        'on',
        'whitelisted',
        1503956389520
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        '24',
        :Test_Save_1,
        'off',
        'in segment all',
        1503956389520
      )
    end

    it 'returns treatments with input validations' do
      expect(subject.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(subject.get_treatment('', 'FACUNDO_TEST')).to eq 'control'
      expect(subject.get_treatment(nil, 'FACUNDO_TEST')).to eq 'control'
      expect(subject.get_treatment('1', '')).to eq 'control'
      expect(subject.get_treatment('1', nil)).to eq 'control'
      expect(subject.get_treatment('24', 'Test_Save_1')).to eq 'off'

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        '24',
        :Test_Save_1,
        'off',
        'in segment all',
        1503956389520
      )
    end

    it 'returns CONTROL with treatment doesnt exist' do
      expect(subject.get_treatment('nico_test', 'random_treatment')).to eq 'control'

      impressions = subject.instance_variable_get(:@impressions_repository).batch
      expect(impressions.size).to eq 0
    end
  end

  context '#get_treatment_with_config' do
    before do
      load_splits_redis(splits)
      load_segment_redis(segment1)
      load_segment_redis(segment2)
      load_segment_redis(segment3)
    end

    it 'returns treatments and configs with FACUNDO_TEST treatment and check impressions' do
      expect(subject.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(subject.get_treatment_with_config('mauro_test', 'FACUNDO_TEST')).to eq(
        treatment: 'off',
        config: nil
      )

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        'mauro_test',
        :FACUNDO_TEST,
        'off',
        'in segment all',
        1506703262916
      )
    end

    it 'returns treatments and configs with MAURO_TEST treatment and check impressions' do
      expect(subject.get_treatment_with_config('mauro', 'MAURO_TEST')).to eq(
        treatment: 'on',
        config: '{"version":"v2"}'
      )
      expect(subject.get_treatment_with_config('test', 'MAURO_TEST')).to eq(
        treatment: 'off',
        config: '{"version":"v1"}'
      )

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'mauro',
        :MAURO_TEST,
        'on',
        'whitelisted',
        1506703262966
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        'test',
        :MAURO_TEST,
        'off',
        'not in split',
        1506703262966
      )
    end

    it 'returns treatments with input validations' do
      expect(subject.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(subject.get_treatment_with_config('', 'FACUNDO_TEST')).to eq(
        treatment: 'control',
        config: nil
      )
      expect(subject.get_treatment_with_config(nil, 'FACUNDO_TEST')).to eq(
        treatment: 'control',
        config: nil
      )
      expect(subject.get_treatment_with_config('1', '')).to eq(
        treatment: 'control',
        config: nil
      )
      expect(subject.get_treatment_with_config('1', nil)).to eq(
        treatment: 'control',
        config: nil
      )
      expect(subject.get_treatment_with_config('24', 'Test_Save_1')).to eq(
        treatment: 'off',
        config: nil
      )

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2      
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        '24',
        :Test_Save_1,
        'off',
        'in segment all',
        1503956389520
      )
    end

    it 'returns CONTROL with treatment doesnt exist' do
      expect(subject.get_treatment_with_config('nico_test', 'random_treatment')).to eq(
        treatment: 'control',
        config: nil
      )

      impressions = subject.instance_variable_get(:@impressions_repository).batch
      expect(impressions.size).to eq 0
    end
  end

  context '#get_treatments' do
    before do
      load_splits_redis(splits)
      load_segment_redis(segment1)
      load_segment_redis(segment2)
      load_segment_redis(segment3)
    end

    it 'returns treatments and check impressions' do
      result = subject.get_treatments('nico_test', ['FACUNDO_TEST', 'MAURO_TEST', 'Test_Save_1'])
      
      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:MAURO_TEST]).to eq 'off'
      expect(result[:Test_Save_1]).to eq 'off'

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :MAURO_TEST,
        'off',
        'not in split',
        1506703262966
      )
      expect_impression(impressions[2],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :Test_Save_1,
        'off',
        'in segment all',
        1503956389520
      )
    end

    it 'returns treatments with input validation' do
      result1 = subject.get_treatments('nico_test', ['FACUNDO_TEST', '', nil])
      result2 = subject.get_treatments('', ['', 'MAURO_TEST', 'Test_Save_1'])
      result3 = subject.get_treatments(nil, ['', 'MAURO_TEST', 'Test_Save_1'])

      expect(result1[:FACUNDO_TEST]).to eq 'on'
      expect(result2[:MAURO_TEST]).to eq 'control'
      expect(result2[:Test_Save_1]).to eq 'control'
      expect(result3[:MAURO_TEST]).to eq 'control'
      expect(result3[:Test_Save_1]).to eq 'control'

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch
      
      # TODO: impressions size is wrong. the exception impressions are not correctly. the correct size is 1.
      expect(impressions.size).to eq 5
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
    end
    
    it 'returns CONTROL with treatment doesnt exist' do
      result = subject.get_treatments('nico_test', ['FACUNDO_TEST', 'random_treatment'])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:random_treatment]).to eq 'control'

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch
      
      # TODO: impressions size is wrong. the exception impressions are not correctly. the correct size is 1.
      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
    end
  end

  context '#get_treatments_with_config' do
    before do
      load_splits_redis(splits)
      load_segment_redis(segment1)
      load_segment_redis(segment2)
      load_segment_redis(segment3)
    end

    it 'returns treatments and check impressions' do
      result = subject.get_treatments_with_config('nico_test', ['FACUNDO_TEST', 'MAURO_TEST', 'Test_Save_1'])
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

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
      expect_impression(impressions[1],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :MAURO_TEST,
        'off',
        'not in split',
        1506703262966
      )
      expect_impression(impressions[2],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :Test_Save_1,
        'off',
        'in segment all',
        1503956389520
      )
    end

    it 'returns treatments with input validation' do
      result1 = subject.get_treatments_with_config('nico_test', ['FACUNDO_TEST', '', nil])
      result2 = subject.get_treatments_with_config('', ['', 'MAURO_TEST', 'Test_Save_1'])
      result3 = subject.get_treatments_with_config(nil, ['', 'MAURO_TEST', 'Test_Save_1'])

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

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch
      
      # TODO: impressions size is wrong. the exception impressions are not correctly. the correct size is 1.
      expect(impressions.size).to eq 5
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
    end
    
    it 'returns CONTROL with treatment doesnt exist' do
      result = subject.get_treatments_with_config('nico_test', ['FACUNDO_TEST', 'random_treatment'])

      expect(result[:FACUNDO_TEST]).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(result[:random_treatment]).to eq(
        treatment: 'control',
        config: nil
      )

      config = subject.instance_variable_get(:@config)
      impressions = subject.instance_variable_get(:@impressions_repository).batch
      
      # TODO: impressions size is wrong. the exception impressions are not correctly. the correct size is 1.
      expect(impressions.size).to eq 2
      expect_impression(impressions[0],
        config.version,
        config.machine_ip,
        config.machine_name,
        'nico_test',
        :FACUNDO_TEST,
        'on',
        'whitelisted',
        1506703262916
      )
    end
  end
end

private

def load_splits_redis(splits_json)
  splits = JSON.parse(splits_json, symbolize_names: true)[:splits]

  splits_repository = subject.instance_variable_get(:@splits_repository)

  splits.each do |split|
    splits_repository.add_split(split)
  end
end

def load_segment_redis(segment_json)
  segments_repository = subject.instance_variable_get(:@segments_repository)

  segments_repository.add_to_segment(JSON.parse(segment_json, symbolize_names: true))
end
