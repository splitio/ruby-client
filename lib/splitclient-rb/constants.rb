# frozen_string_literal: true

class SplitIoClient::Constants
  EXPIRATION_RATE = 600
  CONTROL_PRI = 'control_pri'
  CONTROL_SEC = 'control_sec'
  OCCUPANCY_CHANNEL_PREFIX = '[?occupancy=metrics.publishers]'
  FETCH_BACK_OFF_BASE_RETRIES = 1
  PUSH_CONNECTED = 'PUSH_CONNECTED'
  PUSH_RETRYABLE_ERROR = 'PUSH_RETRYABLE_ERROR'
  PUSH_NONRETRYABLE_ERROR = 'PUSH_NONRETRYABLE_ERROR'
  PUSH_SUBSYSTEM_DOWN = 'PUSH_SUBSYSTEM_DOWN'
  PUSH_SUBSYSTEM_READY = 'PUSH_SUBSYSTEM_READY'
  PUSH_SUBSYSTEM_OFF = 'PUSH_SUBSYSTEM_OFF'
end
  