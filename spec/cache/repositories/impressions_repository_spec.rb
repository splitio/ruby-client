# frozen_string_literal: true

require 'spec_helper'
require 'set'

describe SplitIoClient::Cache::Repositories::ImpressionsRepository do
  RSpec.shared_examples 'impressions specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:repository) { described_class.new(adapter) }
    let(:split_adapter) do
      SplitIoClient::SplitAdapter.new(nil, nil, nil, nil, nil, nil)
    end
    let(:ip) { SplitIoClient.configuration.machine_ip }
    let(:machine_name) { SplitIoClient.configuration.machine_name }
    let(:version) do
      "#{SplitIoClient.configuration.language}-#{SplitIoClient.configuration.version}"
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
      Redis.new.flushall
      SplitIoClient.configuration.labels_enabled = true
      SplitIoClient.configuration.impressions_bulk_size = 2
    end

    it 'adds impressions' do
      repository.add('matching_key1', nil, 'foo', treatment1, 1_478_113_516_002)
      repository.add('matching_key1', nil, 'bar', treatment2, 1_478_113_516_002)
      expect(repository.batch).to match_array(result)

      expect(repository.batch).to eq([])
    end

    it 'adds impressions in bulk' do
      treatments = {
        'foo' => treatment1,
        'bar' => treatment2
      }

      repository.add_bulk('matching_key1', nil, treatments, 1_478_113_516_002)
      expect(repository.batch).to match_array(result)

      expect(repository.batch).to eq([])
    end

    it 'omits label unless labels_enabled' do
      SplitIoClient.configuration.labels_enabled = false

      repository.add('matching_key1', nil, 'foo', treatment1, 1_478_113_516_002)
      expect(repository.batch.first[:i][:r]).to be_nil
    end

    it 'bulk size less than the actual queue' do
      repository.add('matching_key1', nil, 'foo', treatment1, 1_478_113_516_002)
      repository.add('matching_key1', nil, 'bar', treatment2, 1_478_113_516_002)

      SplitIoClient.configuration.impressions_bulk_size = 1

      expect(repository.batch.size).to eq(1)
      expect(repository.batch.size).to eq(1)
    end
  end

  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(
      SplitIoClient::SplitConfig.new.impressions_queue_size
    )
  )
  include_examples 'impressions specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.new.redis_url
  )

  context 'redis adapter' do
    before do
      Redis.new.flushall
    end

    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient.configuration.redis_url) }
    let(:repository) { described_class.new(adapter) }
    let(:treatment) { { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 } }

    it 'expiration set when impressions size match number of elements added' do
      expect(adapter).to receive(:expire).once.with(anything, 3600)

      repository.add('matching_key', nil, 'foo1', treatment, 1_478_113_516_002)
      repository.add('matching_key', nil, 'foo1', treatment, 1_478_113_516_002)
    end

    it 'returns empty array when adapter#get_from_queue raises an exception' do
      allow_any_instance_of(SplitIoClient::Cache::Adapters::RedisAdapter)
        .to receive(:get_from_queue).and_throw(RuntimeError)

      repository.add('matching_key', nil, 'foo1', treatment, 1_478_113_516_002)
      expect(repository.batch).to eq([])
    end
  end

  context 'number of impressions is greater than queue size' do
    before do
      SplitIoClient.configuration = nil
      SplitIoClient.configure(logger: Logger.new('/dev/null'), impressions_queue_size: 1, impressions_bulk_size: 2)
    end

    let(:adapter) do
      SplitIoClient::Cache::Adapters::MemoryAdapter.new(
        SplitIoClient::Cache::Adapters::MemoryAdapters::QueueAdapter.new(
          SplitIoClient::SplitConfig.new.impressions_queue_size
        )
      )
    end
    let(:repository) { described_class.new(adapter) }

    it 'memory adapter drops impressions' do
      treatment = { treatment: 'on', label: 'sample_rule', change_number: 1_533_177_602_748 }

      repository.add('matching_key1', nil, 'foo1', treatment, 1_478_113_516_002)
      repository.add('matching_key2', nil, 'foo1', treatment, 1_478_113_516_002)

      expect(repository.batch.size).to eq(1)
    end
  end
end
