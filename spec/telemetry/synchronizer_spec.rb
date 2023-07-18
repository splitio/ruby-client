# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::Synchronizer do
  let(:log) { StringIO.new }

  context 'Redis' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log), cache_adapter: :redis, mode: :consumer, redis_namespace: 'synch-test') }
    let(:adapter) { config.telemetry_adapter }
    let(:init_producer) { SplitIoClient::Telemetry::InitProducer.new(config) }    
    let(:synchronizer) { SplitIoClient::Telemetry::Synchronizer.new(config, nil, init_producer, nil, nil) }
    let(:config_key) { 'synch-test.SPLITIO.telemetry.init' }    

    it 'synchronize_config with data' do
      adapter.redis.del(config_key)
      synchronizer.synchronize_config(5, 1, ['tag-1'])

      field = "#{config.language}-#{config.version}/#{config.machine_name}/#{config.machine_ip}"
      result = JSON.parse(adapter.find_in_map(config_key, field), symbolize_names: true)

      expect(result[:t][:oM]).to eq('consumer')
      expect(result[:t][:st]).to eq('redis')
      expect(result[:t][:aF]).to eq(5)
      expect(result[:t][:rF]).to eq(1)
      expect(result[:t][:t]).to eq(%w[tag-1])

      adapter.redis.del(config_key)
    end
  end

  context 'Memory' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
    let(:evaluation_consumer) { SplitIoClient::Telemetry::EvaluationConsumer.new(config) }
    let(:init_consumer) { SplitIoClient::Telemetry::InitConsumer.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
    let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
    let(:api_key) { 'Synchronizer-key' }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
    let(:init_producer) { SplitIoClient::Telemetry::InitProducer.new(config) }
    let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer) }
    let(:telemetry_consumers) { { init: init_consumer, runtime: runtime_consumer, evaluation: evaluation_consumer } }
    let(:body_usage) { "{\"lS\":{\"sp\":111111222,\"se\":111111222,\"im\":111111222,\"ic\":111111222,\"ev\":111111222,\"te\":111111222,\"to\":111111222},\"mL\":{\"t\":[0,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"ts\":[0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"tc\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"tcs\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"tr\":[0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]},\"mE\":{\"t\":2,\"ts\":1,\"tc\":1,\"tcs\":0,\"tr\":1},\"hE\":{\"sp\":{},\"se\":{\"400\":1},\"im\":{},\"ic\":{},\"ev\":{\"500\":2,\"501\":1},\"te\":{},\"to\":{}},\"hL\":{\"sp\":[0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"se\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"im\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"ic\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"ev\":[0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"te\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"to\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]},\"tR\":1,\"aR\":1,\"iQ\":3,\"iDe\":1,\"iDr\":2,\"spC\":3,\"seC\":3,\"skC\":7,\"sL\":444555,\"eQ\":4,\"eD\":1,\"sE\":[{\"e\":50,\"d\":222222333,\"t\":222222333},{\"e\":70,\"d\":0,\"t\":222222333},{\"e\":70,\"d\":1,\"t\":222222333}],\"t\":[\"tag-1\",\"tag-2\"],\"ufs\":{\"sp\":5}}" }
    let(:empty_body_usage) { "{\"lS\":{\"sp\":0,\"se\":0,\"im\":0,\"ic\":0,\"ev\":0,\"te\":0,\"to\":0},\"mL\":{\"t\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"ts\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"tc\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"tcs\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"tr\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]},\"mE\":{\"t\":0,\"ts\":0,\"tc\":0,\"tcs\":0,\"tr\":0},\"hE\":{\"sp\":{},\"se\":{},\"im\":{},\"ic\":{},\"ev\":{},\"te\":{},\"to\":{}},\"hL\":{\"sp\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"se\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"im\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"ic\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"ev\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"te\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],\"to\":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]},\"tR\":0,\"aR\":0,\"iQ\":0,\"iDe\":0,\"iDr\":0,\"spC\":0,\"seC\":0,\"skC\":0,\"sL\":0,\"eQ\":0,\"eD\":0,\"sE\":[],\"t\":[],\"ufs\":{\"sp\":0}}" }
    let(:body_custom_config)  { "{\"oM\":0,\"sE\":true,\"st\":\"memory\",\"rR\":{\"sp\":100,\"se\":110,\"im\":120,\"ev\":130,\"te\":140},\"iQ\":5000,\"eQ\":500,\"iM\":0,\"uO\":{\"s\":true,\"e\":true,\"a\":true,\"st\":false,\"t\":false},\"iL\":false,\"hP\":false,\"aF\":1,\"rF\":1,\"tR\":100,\"bT\":2,\"nR\":1,\"t\":[],\"i\":null}" }
    let(:body_default_config) { "{\"oM\":0,\"sE\":true,\"st\":\"memory\",\"rR\":{\"sp\":60,\"se\":60,\"im\":300,\"ev\":60,\"te\":3600},\"iQ\":5000,\"eQ\":500,\"iM\":0,\"uO\":{\"s\":false,\"e\":false,\"a\":false,\"st\":false,\"t\":false},\"iL\":false,\"hP\":false,\"aF\":1,\"rF\":1,\"tR\":500,\"bT\":0,\"nR\":0,\"t\":[],\"i\":null}" }
    let(:body_proxy_config)   { "{\"oM\":0,\"sE\":true,\"st\":\"memory\",\"rR\":{\"sp\":60,\"se\":60,\"im\":300,\"ev\":60,\"te\":3600},\"iQ\":5000,\"eQ\":500,\"iM\":0,\"uO\":{\"s\":false,\"e\":false,\"a\":false,\"st\":false,\"t\":false},\"iL\":false,\"hP\":true,\"aF\":1,\"rF\":1,\"tR\":500,\"bT\":0,\"nR\":0,\"t\":[],\"i\":null}" }

    context 'synchronize_stats' do
      before do
        stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
          .to_return(status: 200, body: 'ok')
      end

      let(:synchronizer) do
        SplitIoClient::Telemetry::Synchronizer.new(config,
                                                   telemetry_consumers,
                                                   init_producer,
                                                   { splits: splits_repository, segments: segments_repository },
                                                   telemetry_api)
      end

      it 'with data' do
        splits_repository.add_split(name: 'foo', trafficTypeName: 'tt_name_1')
        splits_repository.add_split(name: 'bar', trafficTypeName: 'tt_name_2')
        splits_repository.add_split(name: 'baz', trafficTypeName: 'tt_name_1')

        segments_repository.add_to_segment(name: 'foo-1', added: [1, 2, 3], removed: [])
        segments_repository.add_to_segment(name: 'foo-2', added: [1, 2, 3, 4], removed: [])
        segments_repository.add_to_segment(name: 'foo-3', added: [], removed: [])

        splits_repository.set_segment_names(['foo-1', 'foo-2', 'foo-3'])

        runtime_producer.add_tag('tag-1')
        runtime_producer.add_tag('tag-2')
        runtime_producer.record_impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_QUEUED, 3)
        runtime_producer.record_impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_DROPPED, 2)
        runtime_producer.record_impressions_stats(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_DEDUPE, 1)
        runtime_producer.record_events_stats(SplitIoClient::Telemetry::Domain::Constants::EVENTS_QUEUED, 4)
        runtime_producer.record_events_stats(SplitIoClient::Telemetry::Domain::Constants::EVENTS_DROPPED, 1)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::EVENT_SYNC, 111_111_222)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::SPLIT_SYNC, 111_111_222)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::SEGMENT_SYNC, 111_111_222)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::IMPRESSIONS_SYNC, 111_111_222)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::IMPRESSION_COUNT_SYNC, 111_111_222)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::TELEMETRY_SYNC, 111_111_222)
        runtime_producer.record_successful_sync(SplitIoClient::Telemetry::Domain::Constants::TOKEN_SYNC, 111_111_222)
        runtime_producer.record_sync_error(SplitIoClient::Telemetry::Domain::Constants::EVENT_SYNC, 500)
        runtime_producer.record_sync_error(SplitIoClient::Telemetry::Domain::Constants::EVENT_SYNC, 501)
        runtime_producer.record_sync_error(SplitIoClient::Telemetry::Domain::Constants::EVENT_SYNC, 500)
        runtime_producer.record_sync_error(SplitIoClient::Telemetry::Domain::Constants::SEGMENT_SYNC, 400)
        runtime_producer.record_sync_latency(SplitIoClient::Telemetry::Domain::Constants::EVENT_SYNC, 2)
        runtime_producer.record_sync_latency(SplitIoClient::Telemetry::Domain::Constants::SPLIT_SYNC, 6)
        runtime_producer.record_sync_latency(SplitIoClient::Telemetry::Domain::Constants::EVENT_SYNC, 1)
        runtime_producer.record_auth_rejections
        runtime_producer.record_token_refreshes
        runtime_producer.record_streaming_event(SplitIoClient::Telemetry::Domain::Constants::TOKEN_REFRESH, 222_222_333, 222_222_333)
        runtime_producer.record_streaming_event(SplitIoClient::Telemetry::Domain::Constants::SYNC_MODE, 0, 222_222_333)
        runtime_producer.record_streaming_event(SplitIoClient::Telemetry::Domain::Constants::SYNC_MODE, 1, 222_222_333)
        runtime_producer.record_session_length(444_555)
        runtime_producer.record_updates_from_sse(SplitIoClient::Telemetry::Domain::Constants::SPLITS)
        runtime_producer.record_updates_from_sse(SplitIoClient::Telemetry::Domain::Constants::SPLITS)
        runtime_producer.record_updates_from_sse(SplitIoClient::Telemetry::Domain::Constants::SPLITS)
        runtime_producer.record_updates_from_sse(SplitIoClient::Telemetry::Domain::Constants::SPLITS)
        runtime_producer.record_updates_from_sse(SplitIoClient::Telemetry::Domain::Constants::SPLITS)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 1)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 3)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 2)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENT, 1)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS, 2)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS, 3)
        evaluation_producer.record_latency(SplitIoClient::Telemetry::Domain::Constants::TRACK, 3)
        evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)
        evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT)
        evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENTS)
        evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TRACK)
        evaluation_producer.record_exception(SplitIoClient::Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG)

        synchronizer.synchronize_stats

        expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
          .with(body: body_usage)).to have_been_made
      end

      it 'without data' do
        synchronizer.synchronize_stats

        expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
          .with(body: empty_body_usage)).to have_been_made
      end
    end

    context 'synchronize_config' do
      before do
        stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
          .to_return(status: 200, body: 'ok')
        
        SplitIoClient.load_factory_registry
      end
      
      it 'with custom data' do
        config.features_refresh_rate = 100
        config.segments_refresh_rate = 110
        config.impressions_refresh_rate = 120
        config.events_push_rate = 130
        config.telemetry_refresh_rate = 140
        config.base_uri = 'https://sdk.test.io/api/'
        config.events_uri = 'https://events.test.io/api/'
        config.auth_service_url = 'https://auth.test.io/api/auth'

        init_producer.record_bur_timeout
        init_producer.record_bur_timeout
        init_producer.record_non_ready_usages

        synchronizer = SplitIoClient::Telemetry::Synchronizer.new(config,
                                                                  telemetry_consumers,
                                                                  init_producer,
                                                                  { splits: splits_repository, segments: segments_repository },
                                                                  telemetry_api)

        synchronizer.synchronize_config(1, 1, 100)

        expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
          .with(body: body_custom_config)).to have_been_made
      end

      it 'with default data' do
        synchronizer = SplitIoClient::Telemetry::Synchronizer.new(config,
                                                                  telemetry_consumers,
                                                                  init_producer,
                                                                  { splits: splits_repository, segments: segments_repository },
                                                                  telemetry_api)
        
        synchronizer.synchronize_config(1, 1, 500)
  
        expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
          .with(body: body_default_config)).to have_been_made
      end

      it 'with proxy' do        
        ENV['HTTPS_PROXY'] = 'https://proxy.test.io/api/v1/metrics/config'

        synchronizer = SplitIoClient::Telemetry::Synchronizer.new(config,
                                                                  telemetry_consumers,
                                                                  init_producer,
                                                                  { splits: splits_repository, segments: segments_repository },
                                                                  telemetry_api)

        synchronizer.synchronize_config(1, 1, 500)

        expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/config')
          .with(body: body_proxy_config)).to have_been_made
      end
    end
  end
end
