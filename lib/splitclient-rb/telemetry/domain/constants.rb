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

        SSE_CONNECTION_ESTABLISHED = 'sse_connection_established'
        OCCUPANCY_PRI = 'occupancy_pri'
        OCCUPANCY_SEC = 'occupancy_sec'
        STREAMING_STATUS = 'streaming_status'
        CONNECTION_ERROR = 'connection_error'
        TOKEN_REFRESH = 'token_refresh'
        ABLY_ERROR = 'ably_error'
        SYNC_MODE = 'sync_mode'

        TREATMENT = 'treatment'
        TREATMENTS = 'treatments'
        TREATMENT_WITH_CONFIG = 'treatment_with_config'
        TREATMENTS_WITH_CONFIG = 'treatments_with_config'
        TRACK = 'track'
      end
    end
  end
end
