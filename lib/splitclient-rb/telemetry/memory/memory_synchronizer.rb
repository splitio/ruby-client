# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    class MemorySynchronizer
      def initialize(config,
                     telemtry_consumers,
                     repositories,
                     telemetry_api)
        @config = config
        @telemetry_init_consumer = telemtry_consumers[:init]
        @telemetry_runtime_consumer = telemtry_consumers[:runtime]
        @telemtry_evaluation_consumer = telemtry_consumers[:evaluation]
        @splits_repository = repositories[:splits]
        @segments_repository = repositories[:segments]
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
                          @telemetry_runtime_consumer.pop_tags,
                          @telemetry_runtime_consumer.pop_updates_from_sse)

        @telemetry_api.record_stats(format_stats(usage))
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end

      def synchronize_config(active_factories = nil, redundant_active_factories = nil, time_until_ready = nil, flag_sets = nil, flag_sets_invalid = nil)
        rates = Rates.new(@config.features_refresh_rate,
                          @config.segments_refresh_rate,
                          @config.impressions_refresh_rate,
                          @config.events_push_rate,
                          @config.telemetry_refresh_rate)

        url_overrides = UrlOverrides.new(@config.base_uri != SplitConfig.default_base_uri.chomp('/'),
                                         @config.events_uri != SplitConfig.default_events_uri.chomp('/'),
                                         @config.auth_service_url != SplitConfig.default_auth_service_url,
                                         @config.streaming_service_url != SplitConfig.default_streaming_service_url,
                                         @config.telemetry_service_url != SplitConfig.default_telemetry_service_url)

        active_factories ||= SplitIoClient.split_factory_registry.active_factories
        redundant_active_factories ||= SplitIoClient.split_factory_registry.redundant_active_factories
        time_until_ready ||= ((Time.now.to_f - @config.sdk_start_time) * 1000.0).to_i

        init_config = ConfigInit.new(mode,
                                     'memory',
                                     active_factories,
                                     redundant_active_factories,
                                     @telemetry_runtime_consumer.pop_tags,
                                     flag_sets,
                                     flag_sets_invalid,
                                     @config.streaming_enabled,
                                     rates,
                                     url_overrides,
                                     @config.impressions_queue_size,
                                     @config.events_queue_size,
                                     impressions_mode,
                                     !@config.impression_listener.nil?,
                                     http_proxy_detected?,
                                     time_until_ready,
                                     @telemetry_init_consumer.bur_timeouts,
                                     @telemetry_init_consumer.non_ready_usages)

        @telemetry_api.record_init(fornat_init_config(init_config))
      rescue StandardError => e
        @config.log_found_exception(__method__.to_s, e)
      end

      private

      def fornat_init_config(init)
        {
          oM: init.om,
          sE: init.se,
          st: init.st,
          rR: {
            sp: init.rr.sp,
            se: init.rr.se,
            im: init.rr.im,
            ev: init.rr.ev,
            te: init.rr.te
          },
          iQ: init.iq,
          eQ: init.eq,
          iM: init.im,
          uO: {
            s: init.uo.s,
            e: init.uo.e,
            a: init.uo.a,
            st: init.uo.st,
            t: init.uo.t
          },
          iL: init.il,
          hP: init.hp,
          aF: init.af,
          rF: init.rf,
          tR: init.tr,
          bT: init.bt,
          nR: init.nr,
          t: init.t,
          i: init.i,
          fsT: init.fsT,
          fsI: init.fsI
        }
      end

      def format_stats(usage)
        {
          lS: usage.ls.to_h,
          mL: {
            t: usage.ml[Telemetry::Domain::Constants::TREATMENT],
            ts: usage.ml[Telemetry::Domain::Constants::TREATMENTS],
            tc: usage.ml[Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG],
            tcs: usage.ml[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG],
            tf: usage.ml[Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SET],
            tfs: usage.ml[Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SETS],
            tcf: usage.ml[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SET],
            tcfs: usage.ml[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SETS],
            tr: usage.ml[Telemetry::Domain::Constants::TRACK]
          },
          mE: {
            t: usage.me[Telemetry::Domain::Constants::TREATMENT],
            ts: usage.me[Telemetry::Domain::Constants::TREATMENTS],
            tc: usage.me[Telemetry::Domain::Constants::TREATMENT_WITH_CONFIG],
            tcs: usage.me[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG],
            tf: usage.me[Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SET],
            tfs: usage.me[Telemetry::Domain::Constants::TREATMENTS_BY_FLAG_SETS],
            tcf: usage.me[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SET],
            tcfs: usage.me[Telemetry::Domain::Constants::TREATMENTS_WITH_CONFIG_BY_FLAG_SETS],
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
          t: usage.t,
          ufs: usage.ufs.to_h
        }
      end

      def http_proxy_detected?
        !ENV['HTTP_PROXY'].nil? || !ENV['HTTPS_PROXY'].nil?
      end

      def mode
        case @config.mode
        when :customer
          1
        else
          0
        end
      end

      def impressions_mode
        case @config.impressions_mode
        when :optimized
          0
        when :debug
          1
        else
          2
        end
      end
    end
  end
end
