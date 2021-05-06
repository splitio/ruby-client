# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    LastSynchronization = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
    HttpErrors = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
    HttpLatencies = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
    StreamingEvent = Struct.new(:type, :data, :timestamp)
  end
end
