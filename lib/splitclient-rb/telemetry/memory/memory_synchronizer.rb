# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemorySynchronizer < Synchronizer
      def initialize(config,
                     telemtry_consumers,
                     splits_repository,
                     segments_repository,
                     telemetry_api)
        @config = config
        @telemetry_init_consumer = telemtry_consumers[:init]
        @telemetry_runtime_consumer = telemtry_consumers[:runtime]
        @telemtry_evaluation_consumer = telemtry_consumers[:evaluation]
        @splits_repository = splits_repository
        @segments_repository = segments_repository
        @telemetry_api = telemetry_api
      end

      def synchronize_stats
        usage = Usage.new(@telemetry_runtime_consumer.last_synchronizations,
                          @telemtry_evaluation_consumer.pop_latencies,
                          @telemtry_evaluation_consumer.pop_exceptions,
                          @telemetry_runtime_consumer.pop_http_errors,
                          @telemetry_runtime_consumer.pop_http_latencies,
                          @telemetry_runtime_consumer.pop_token_refreshes,
                          @telemetry_runtime_consumer.pop_auth_rejections,
                          @telemetry_runtime_consumer.impressions_stats(Domain::Constants::IMPRESSIONS_QUEUED),
                          @telemetry_runtime_consumer.impressions_stats(Domain::Constants::IMPRESSIONS_DEDUPE),
                          @telemetry_runtime_consumer.impressions_stats(Domain::Constants::IMPRESSIONS_DROPPED),
                          @splits_repository.splits_count,
                          @segments_repository.segments_count,
                          @segments_repository.segment_keys_count,
                          @telemetry_runtime_consumer.session_length,
                          @telemetry_runtime_consumer.events_stats(Domain::Constants::EVENTS_QUEUED),
                          @telemetry_runtime_consumer.events_stats(Domain::Constants::EVENTS_DROPPED),
                          @telemetry_runtime_consumer.pop_streaming_events,
                          @telemetry_runtime_consumer.pop_tags)

        @telemetry_api.record_stats(format_stats(usage))
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      def synchronize_config(init_config, timed_until_ready, factory_instances, tags)
        
      rescue StandardError => error
        @config.log_found_exception(__method__.to_s, error)
      end

      private

      def format_stats(usage)
        {
          lS: usage.ls.to_h,
          mL: {
            t: usage.ml[Telemetry::Domain::Constants::TREATMENT],
            ts: usage.ml[Telemetry::Domain::Constants::TREATMENTS],
            tc: usage.ml[Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG],
            tcs: usage.ml[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG],
            tr: usage.ml[Telemetry::Domain::Constants::TRACK]
          },
          mE: {
            t: usage.me[Telemetry::Domain::Constants::TREATMENT],
            ts: usage.me[Telemetry::Domain::Constants::TREATMENTS],
            tc: usage.me[Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG],
            tcs: usage.me[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG],
            tr: usage.me[Telemetry::Domain::Constants::TRACK]
          },
          hE: {
            sp: usage.he.sp,
            se: usage.he.se,
            im: usage.he.im,
            ic: usage.he.ic,
            ev: usage.he.ev,
            te: usage.he.te,
            to: usage.he.to
          },
          hL: {
            sp: usage.hl.sp,
            se: usage.hl.se,
            im: usage.hl.im,
            ic: usage.hl.ic,
            ev: usage.hl.ev,
            te: usage.hl.te,
            to: usage.hl.to
          },
          tR: usage.tr,
          aR: usage.ar,
          iQ: usage.iq,
          iDe: usage.ide,
          iDr: usage.idr,
          spC: usage.spc,
          seC: usage.sec,
          skC: usage.skc,
          sL: usage.sl,
          eQ: usage.eq,
          eD: usage.ed,
          sE: usage.se,
          t: usage.t
        }
      end
    end
  end
end
