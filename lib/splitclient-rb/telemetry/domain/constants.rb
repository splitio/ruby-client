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
      end
    end
  end
end
