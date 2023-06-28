# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    module Domain
      class Constants
        BUR_TIMEOUT = 'bur_timeout'
        NON_READY_USAGES = 'non_ready_usages'

        IMPRESSIONS_DROPPED = 'impressions_dropped'
        IMPRESSIONS_DEDUPE = 'impressions_deduped'
        IMPRESSIONS_QUEUED = 'impressions_queued'

        EVENTS_DROPPED = 'events_dropped'
        EVENTS_QUEUED = 'events_queued'

        SPLIT_SYNC = 'split_sync'
        SEGMENT_SYNC = 'segment_sync'
        IMPRESSIONS_SYNC = 'impressions_sync'
        IMPRESSION_COUNT_SYNC = 'impression_count_sync'
        EVENT_SYNC = 'event_sync'
        TELEMETRY_SYNC = 'telemetry_sync'
        TOKEN_SYNC = 'token_sync'

        SSE_CONNECTION_ESTABLISHED = 0
        OCCUPANCY_PRI = 10
        OCCUPANCY_SEC = 20
        STREAMING_STATUS = 30
        CONNECTION_ERROR = 40
        TOKEN_REFRESH = 50
        ABLY_ERROR = 60
        SYNC_MODE = 70

        TREATMENT = 'treatment'
        TREATMENTS = 'treatments'
        TREATMENT_WITH_CONFIG = 'treatmentWithConfig'
        TREATMENTS_WITH_CONFIG = 'treatmentsWithConfig'
        TRACK = 'track'

        SPLITS = "splits"
      end
    end
  end
end
