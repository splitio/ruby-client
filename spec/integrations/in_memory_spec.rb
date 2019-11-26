# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient do
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

  context '#get_treatment' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')
      mock_segment_changes('segment3', segment3, '1470947453879')
    end

    it 'returns treatments with FACUNDO_TEST feature and check impressions' do
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('mauro_test', 'FACUNDO_TEST')).to eq 'off'

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: 'FACUNDO_TEST',
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'mauro_test',
        feature: 'FACUNDO_TEST',
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[1], actual_impression)
    end

    it 'returns treatments with Test_Save_1 feature and check impressions' do
      expect(client.get_treatment('1', 'Test_Save_1')).to eq 'on'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: '1',
        feature: 'Test_Save_1',
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_503_956_389_520
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: '24',
        feature: 'Test_Save_1',
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_503_956_389_520
      }
      expect_impression(impressions[1], actual_impression)
    end

    it 'returns treatments with input validations' do
      expect(client.get_treatment('nico_test', 'FACUNDO_TEST')).to eq 'on'
      expect(client.get_treatment('', 'FACUNDO_TEST')).to eq 'control'
      expect(client.get_treatment(nil, 'FACUNDO_TEST')).to eq 'control'
      expect(client.get_treatment('1', '')).to eq 'control'
      expect(client.get_treatment('1', nil)).to eq 'control'
      expect(client.get_treatment('24', 'Test_Save_1')).to eq 'off'

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: 'FACUNDO_TEST',
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: '24',
        feature: 'Test_Save_1',
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_503_956_389_520
      }
      expect_impression(impressions[1], actual_impression)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      expect(client.get_treatment('nico_test', 'random_treatment')).to eq 'control'

      impressions = client.instance_variable_get(:@impressions_repository).batch
      expect(impressions.size).to eq 0
    end
  end

  context '#get_treatment_with_config' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')
      mock_segment_changes('segment3', segment3, '1470947453879')
    end

    it 'returns treatments and configs with FACUNDO_TEST treatment and check impressions' do
      expect(client.get_treatment_with_config('nico_test', 'FACUNDO_TEST')).to eq(
        treatment: 'on',
        config: '{"color":"green"}'
      )
      expect(client.get_treatment_with_config('mauro_test', 'FACUNDO_TEST')).to eq(
        treatment: 'off',
        config: nil
      )

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: 'FACUNDO_TEST',
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'mauro_test',
        feature: 'FACUNDO_TEST',
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[1], actual_impression)
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

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'mauro',
        feature: 'MAURO_TEST',
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_966
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'test',
        feature: 'MAURO_TEST',
        treatment: 'off',
        condition: 'not in split',
        change_number: 1_506_703_262_966
      }
      expect_impression(impressions[1], actual_impression)
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

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 2

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: 'FACUNDO_TEST',
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: '24',
        feature: 'Test_Save_1',
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_503_956_389_520
      }
      expect_impression(impressions[1], actual_impression)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      expect(client.get_treatment_with_config('nico_test', 'random_treatment')).to eq(
        treatment: 'control',
        config: nil
      )

      impressions = client.instance_variable_get(:@impressions_repository).batch
      expect(impressions.size).to eq 0
    end
  end

  context '#get_treatments' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')
      mock_segment_changes('segment3', segment3, '1470947453879')
    end

    it 'returns treatments and check impressions' do
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST MAURO_TEST Test_Save_1])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:MAURO_TEST]).to eq 'off'
      expect(result[:Test_Save_1]).to eq 'off'

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :FACUNDO_TEST,
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :MAURO_TEST,
        treatment: 'off',
        condition: 'not in split',
        change_number: 1_506_703_262_966
      }
      expect_impression(impressions[1], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :Test_Save_1,
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_503_956_389_520
      }
      expect_impression(impressions[2], actual_impression)
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

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch
      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :FACUNDO_TEST,
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }

      expect(impressions.size).to eq 1
      expect_impression(impressions[0], actual_impression)
    end

    it 'returns CONTROL with treatment doesnt exist' do
      result = client.get_treatments('nico_test', %w[FACUNDO_TEST random_treatment])

      expect(result[:FACUNDO_TEST]).to eq 'on'
      expect(result[:random_treatment]).to eq 'control'

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch
      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :FACUNDO_TEST,
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }

      expect(impressions.size).to eq 1
      expect_impression(impressions[0], actual_impression)
    end
  end

  context '#get_treatments_with_config' do
    before do
      mock_split_changes(splits)
      mock_segment_changes('segment1', segment1, '-1')
      mock_segment_changes('segment1', segment1, '1470947453877')
      mock_segment_changes('segment2', segment2, '-1')
      mock_segment_changes('segment2', segment2, '1470947453878')
      mock_segment_changes('segment3', segment3, '-1')
      mock_segment_changes('segment3', segment3, '1470947453879')
    end

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

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch

      expect(impressions.size).to eq 3
      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :FACUNDO_TEST,
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }
      expect_impression(impressions[0], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :MAURO_TEST,
        treatment: 'off',
        condition: 'not in split',
        change_number: 1_506_703_262_966
      }
      expect_impression(impressions[1], actual_impression)

      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :Test_Save_1,
        treatment: 'off',
        condition: 'in segment all',
        change_number: 1_503_956_389_520
      }
      expect_impression(impressions[2], actual_impression)
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

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch
      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :FACUNDO_TEST,
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }

      expect(impressions.size).to eq 1
      expect_impression(impressions[0], actual_impression)
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

      config = client.instance_variable_get(:@config)
      impressions = client.instance_variable_get(:@impressions_repository).batch
      actual_impression = {
        version: config.version,
        machine_ip: config.machine_ip,
        machine_name: config.machine_name,
        key: 'nico_test',
        feature: :FACUNDO_TEST,
        treatment: 'on',
        condition: 'whitelisted',
        change_number: 1_506_703_262_916
      }

      expect(impressions.size).to eq 1
      expect_impression(impressions[0], actual_impression)
    end
  end
end

private

def expect_impression(imp, actual_imp)
  expect(imp[:m][:s]).to eq "ruby-#{actual_imp[:version]}"
  expect(imp[:m][:i]).to eq actual_imp[:machine_ip]
  expect(imp[:m][:n]).to eq actual_imp[:machine_name]
  expect(imp[:i][:k]).to eq actual_imp[:key]
  expect(imp[:i][:f]).to eq actual_imp[:feature]
  expect(imp[:i][:t]).to eq actual_imp[:treatment]
  expect(imp[:i][:r]).to eq actual_imp[:condition]
  expect(imp[:i][:c]).to eq actual_imp[:change_number]
end

def mock_split_changes(splits_json)
  stub_request(:get, 'https://sdk.split.io/api/splitChanges?since=-1')
    .to_return(status: 200, body: splits_json)
end

def mock_segment_changes(segment_name, segment_json, since)
  stub_request(:get, "https://sdk.split.io/api/segmentChanges/#{segment_name}?since=#{since}")
    .to_return(status: 200, body: segment_json)
end
