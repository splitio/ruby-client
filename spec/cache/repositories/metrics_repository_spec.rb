# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Cache::Repositories::MetricsRepository do
  RSpec.shared_examples 'metrics specs' do |cache_adapter|
    let(:adapter) { cache_adapter }
    let(:repository) { described_class.new(adapter) }
    let(:binary_search) { SplitIoClient::BinarySearchLatencyTracker.new }

    before :each do
      Redis.new.flushall
    end

    it 'does not return zero latencies' do
      repository.add_latency('foo', 0, binary_search)

      expect(repository.latencies.keys).to eq(%w[foo])
    end

    it 'increments non-zero latencies' do
      repository.add_latency('sdk.get_treatment', 1, binary_search)
      repository.add_latency('sdk.get_treatment', 22, binary_search)
      repository.add_latency('sdk.get_treatment', 21, binary_search)
      repository.add_latency('sdk.get_treatment', 19, binary_search)
      repository.add_latency('sdk.get_treatments', 2, binary_search)
      repository.add_latency('sdk.get_treatments', 5, binary_search)
      repository.add_latency('sdk.get_treatment_with_config', 5, binary_search)
      repository.add_latency('sdk.get_treatments_with_config', 15, binary_search)

      expect(repository.latencies).to eq(
        'sdk.get_treatment' => [1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'sdk.get_treatments' => [0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'sdk.get_treatment_with_config' => [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        'sdk.get_treatments_with_config' => [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      )
    end
  end

  include_examples 'metrics specs', SplitIoClient::Cache::Adapters::RedisAdapter.new(
    SplitIoClient::SplitConfig.default_redis_url
  )

  include_examples 'metrics specs', SplitIoClient::Cache::Adapters::MemoryAdapter.new(
    SplitIoClient::Cache::Adapters::MemoryAdapters::MapAdapter.new
  )

  context 'fix latencies for redis' do
    before do
      Redis.new.flushall
    end

    let(:adapter) { SplitIoClient::Cache::Adapters::RedisAdapter.new(SplitIoClient.configuration.redis_url) }
    let(:repository) { described_class.new(adapter) }

    it 'detects and deletes incorrect latency patterns from the repository' do
      latency_pattern = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-*/latency.*"

      expect(adapter.find_strings_by_pattern(latency_pattern)).to be_empty

      # incorrect patterns
      time_pattern = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-5.1.3.pre.rc2" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.splitChangeFetcher.time"

      adapter.set_string(time_pattern, '33')

      get_treatment_pattern1 = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-3" \
        '/172.17.0.2/latency.sdk.get_treatment.1'

      adapter.set_string(get_treatment_pattern1, '1')

      get_treatment_pattern2 = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-4.1" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatment.22"

      adapter.set_string(get_treatment_pattern2, '2')

      get_treatment_pattern3 = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-5.1.2" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatment.7"

      adapter.set_string(get_treatment_pattern3, '5')

      get_treatments_pattern = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-6.3.2" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatments"

      adapter.set_string(get_treatments_pattern, '1')

      get_treatments_with_config_pattern =
        "#{SplitIoClient.configuration.redis_namespace}" \
          "/#{SplitIoClient.configuration.language}-6.4.2" \
          "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatments_with_config"

      adapter.set_string(get_treatments_with_config_pattern, '6')

      # correct patterns - must not be deleted
      keep_get_treatment_pattern1 = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-3" \
        '/172.17.0.2/latency.sdk.get_treatment.bucket.1'

      adapter.set_string(keep_get_treatment_pattern1, '1')

      keep_get_treatment_pattern2 = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-4.1" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatment.bucket.22"

      adapter.set_string(keep_get_treatment_pattern2, '2')

      keep_get_treatment_pattern3 = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-5.1.2" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatment.bucket.7"

      adapter.set_string(keep_get_treatment_pattern3, '5')

      keep_get_treatments_pattern = "#{SplitIoClient.configuration.redis_namespace}" \
        "/#{SplitIoClient.configuration.language}-6.3.2" \
        "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatments.bucket.6"

      adapter.set_string(keep_get_treatments_pattern, '1')

      keep_get_treatments_with_config_pattern =
        "#{SplitIoClient.configuration.redis_namespace}" \
          "/#{SplitIoClient.configuration.language}-6.4.2" \
          "/#{SplitIoClient.configuration.machine_ip}/latency.sdk.get_treatments_with_config.bucket.22"

      adapter.set_string(keep_get_treatments_with_config_pattern, '6')

      expect(adapter.find_strings_by_pattern(latency_pattern).size).to eq 11

      repository.fix_latencies

      expect(adapter.find_strings_by_pattern(latency_pattern)).to match_array(
        [
          keep_get_treatment_pattern1,
          keep_get_treatment_pattern2,
          keep_get_treatment_pattern3,
          keep_get_treatments_pattern,
          keep_get_treatments_with_config_pattern
        ]
      )
    end
  end
end
