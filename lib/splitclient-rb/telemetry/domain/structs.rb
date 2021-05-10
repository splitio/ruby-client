# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    LastSynchronization = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
    HttpErrors = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
    HttpLatencies = Struct.new(:splits, :segments, :impressions, :impression_count, :events, :telemetry, :token)
    StreamingEvent = Struct.new(:type, :data, :timestamp)

    # sp: splits, se: segmentos, im: impressions, ev: events, t: telemetry
    Rates = Struct.new(:sp, :se, :im, :ev, :te)

    # s: sdkUrl, e: eventsUrl, a: authUrl, st: streamUrl, t: telemetryUrl
    UrlOverrides = Struct.new(:s, :e, :a, :st, :t)

    # om: operationMode, se: streamingEnabled, st: storage, rr: refreshRate, uo: urlOverrides, iq: impressionsQueueSize
    # eq: eventsQueueSize, im: impressionsMode, il: impressionListenerEnabled, hp: httpProxyDetected, af: activeFactories,
    # rf: redundantActiveFactories, tr: timeUntilSdkReady, bt: burTimeouts, nr: sdkNotReadyUsage, t: tags, i: integrations
    ConfigInit = Struct.new(:om, :st, :af, :rf, :t, :se, :rr, :uo, :iq, :eq, :im, :il, :hp, :tr, :bt, :nr, :i)
  end
end
