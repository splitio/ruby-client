# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    LastSynchronization = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
  end
end
