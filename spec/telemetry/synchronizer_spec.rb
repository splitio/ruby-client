# frozen_string_literal: true

require 'spec_helper'

describe SplitIoClient::Telemetry::Synchronizer do
  let(:log) { StringIO.new }

  context 'Memory' do
    let(:config) { SplitIoClient::SplitConfig.new(logger: Logger.new(log)) }
    let(:evaluation_consumer) { SplitIoClient::Telemetry::EvaluationConsumer.new(config) }
    let(:init_consumer) { SplitIoClient::Telemetry::InitConsumer.new(config) }
    let(:runtime_consumer) { SplitIoClient::Telemetry::RuntimeConsumer.new(config) }
    let(:splits_repository) { SplitIoClient::Cache::Repositories::SplitsRepository.new(config) }
    let(:segments_repository) { SplitIoClient::Cache::Repositories::SegmentsRepository.new(config) }
    let(:api_key) { 'api-key-test' }
    let(:runtime_producer) { SplitIoClient::Telemetry::RuntimeProducer.new(config) }
    let(:evaluation_producer) { SplitIoClient::Telemetry::EvaluationProducer.new(config) }
    let(:telemetry_api) { SplitIoClient::Api::TelemetryApi.new(config, api_key, runtime_producer) }
    let(:telemetry_consumers) do
      { init: init_consumer, runtime: runtime_consumer, evaluation: evaluation_consumer }
    end
    let(:body_usage) { "{\"ls\":{\"sp\":111111222,\"se\":111111222,\"im\":111111222,\"ic\":111111222,\"ev\":111111222,\"te\":111111222,\"to\":111111222},\"ml\":{\"t\":[1,3,2,1],\"ts\":[2,3],\"tc\":[],\"tcs\":[],\"tr\":[3]},\"me\":{\"t\":2,\"ts\":1,\"tc\":1,\"tcs\":0,\"tr\":1},\"he\":{\"sp\":[],\"se\":[{\"400\":1}],\"im\":[],\"ic\":[],\"ev\":[{\"500\":2},{\"501\":1}],\"te\":[],\"to\":[]},\"hl\":{\"sp\":[6],\"se\":[],\"im\":[],\"ic\":[],\"ev\":[2,1],\"te\":[],\"to\":[]},\"tr\":1,\"ar\":1,\"iq\":3,\"ide\":1,\"idr\":2,\"spc\":3,\"sec\":3,\"skc\":7,\"sl\":444555,\"eq\":4,\"ed\":1,\"se\":[{\"e\":\"token_refresh\",\"d\":222222333,\"t\":222222333},{\"e\":\"sync_mode\",\"d\":0,\"t\":222222333},{\"e\":\"sync_mode\",\"d\":1,\"t\":222222333}],\"t\":[\"tag-1\",\"tag-2\"]}" }
    let(:empty_body_usage) { "{\"ls\":{\"sp\":0,\"se\":0,\"im\":0,\"ic\":0,\"ev\":0,\"te\":0,\"to\":0},\"ml\":{\"t\":[],\"ts\":[],\"tc\":[],\"tcs\":[],\"tr\":[]},\"me\":{\"t\":0,\"ts\":0,\"tc\":0,\"tcs\":0,\"tr\":0},\"he\":{\"sp\":[],\"se\":[],\"im\":[],\"ic\":[],\"ev\":[],\"te\":[],\"to\":[]},\"hl\":{\"sp\":[],\"se\":[],\"im\":[],\"ic\":[],\"ev\":[],\"te\":[],\"to\":[]},\"tr\":0,\"ar\":0,\"iq\":0,\"ide\":0,\"idr\":0,\"spc\":0,\"sec\":0,\"skc\":0,\"sl\":0,\"eq\":0,\"ed\":0,\"se\":[],\"t\":[]}" }
    let(:synchronizer) do
      SplitIoClient::Telemetry::Synchronizer.new(config,
                                                 telemetry_consumers,
                                                 splits_repository,
                                                 segments_repository,
                                                 telemetry_api)
    end

    it 'synchronize_stats with data' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')

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

    it 'synchronize_stats without data' do
      stub_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .to_return(status: 200, body: 'ok')

      synchronizer.synchronize_stats

      expect(a_request(:post, 'https://telemetry.split.io/api/v1/metrics/usage')
        .with(body: empty_body_usage)).to have_been_made
    end
  end
end
