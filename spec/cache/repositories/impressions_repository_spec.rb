# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'Impressions Repository' do
    let(:ip) { config.machine_ip }
    let(:machine_name) { config.machine_name }
    let(:version) do
      "#{config.language}-#{config.version}"
    end

    let(:treatment1) { { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 } }
    let(:treatment2) { { treatment: 'off', label: 'sample_rule', change_number: 1_533_177_602_749 } }
    let(:result) do
      [
        {
          m: { s: version, i: ip, n: machine_name },
          i: {
            k: 'matching_key1',
            b: nil,
            f: :foo,
            t: 'on',
            r: 'sample_rule',
            c: 1_533_177_602_748,
            m: 1_478_113_516_002
          }
        },
        {
          m: { s: version, i: ip, n: machine_name },
          i: {
            k: 'matching_key1',
            b: nil,
            f: :bar,
            t: 'off',
            r: 'sample_rule',
            c: 1_533_177_602_749,
            m: 1_478_113_516_002
          }
        }
      ]
    end

    before :each do
      config.labels_enabled = true
      config.impressions_bulk_size = 2
      Redis.new.flushall
    end

    it 'adds impressions' do
      repository.add('matching_key1', nil, :foo, treatment1, 1_478_113_516_002)
      repository.add('matching_key1', nil, :bar, treatment2, 1_478_113_516_002)

      result.each { |h| h.delete(:m) } if config.impressions_adapter.is_a? SplitIoClient::Cache::Adapters::MemoryAdapter

      expect(repository.batch).to match_array(result)

      expect(repository.batch).to eq([])
    end

    it 'adds impressions in bulk' do
      treatments = {
        foo: treatment1,
        bar: treatment2
      }

      repository.add_bulk('matching_key1', nil, treatments, 1_478_113_516_002)

      result.each { |h| h.delete(:m) } if config.impressions_adapter.is_a? SplitIoClient::Cache::Adapters::MemoryAdapter

      expect(repository.batch).to match_array(result)

      expect(repository.batch).to eq([])
    end

    it 'omits label unless labels_enabled' do
      config.labels_enabled = false

      repository.add('matching_key1', nil, :foo, treatment1, 1_478_113_516_002)
      expect(repository.batch.first[:i][:r]).to be_nil
    end

    it 'bulk size less than the actual queue' do
      repository.add('matching_key1', nil, :foo, treatment1, 1_478_113_516_002)
      repository.add('matching_key1', nil, :bar, treatment2, 1_478_113_516_002)
      config.impressions_bulk_size = 1

      expect(repository.batch.size).to eq(1)
      expect(repository.batch.size).to eq(1)
    end
  end

  describe 'with Memory Adapter' do
    let(:config) { @default_config }

    let(:repository) { described_class.new(config) }

    it_behaves_like 'Impressions Repository'

    context 'number of impressions is greater than queue size' do
      let(:config) do
        SplitIoClient::SplitConfig.new(
          impressions_queue_size: 1
        )
      end

      it 'memory adapter drops impressions' do
        treatment = { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 }

        repository.add('matching_key1', nil, :foo1, treatment, 1_478_113_516_002)
        repository.add('matching_key2', nil, :foo1, treatment, 1_478_113_516_002)

        expect(repository.batch.size).to eq(1)
      end
    end
  end

  describe 'with Redis Adapter' do
    let(:config) do
      SplitIoClient::SplitConfig.new(
        labels_enabled: true,
        impressions_bulk_size: 2,
        cache_adapter: :redis
      )
    end

    let(:repository) { described_class.new(config) }

    it_behaves_like 'Impressions Repository'

    let(:treatment) { { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 } }

    before :each do
      Redis.new.flushall
    end

    it 'expiration set when impressions size match number of elements added' do
      expect(config.impressions_adapter).to receive(:expire).once.with(anything, 3600)
      repository.add('matching_key', nil, :foo1, treatment, 1_478_113_516_002)
      repository.add('matching_key', nil, :foo1, treatment, 1_478_113_516_002)
    end

    it 'returns empty array when adapter#get_from_queue raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Adapters::RedisAdapter)
        .to receive(:get_from_queue).and_throw(RuntimeError)

      repository.add('matching_key', nil, :foo1, treatment, 1_478_113_516_002)
      expect(repository.batch).to eq([])
    end
  end
end
