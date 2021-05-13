# frozen_string_literal: true

module SplitIoClient
  module Telemetry
    # sp: splits, se: segments, im: impressions, ic:impression count, ev: events, te: telemetry, to: token.
    LastSynchronization = Struct.new(:sp, :se, :im, :ic, :ev, :te, :to)
    HttpErrors = Struct.new(:sp, :se, :im, :ic, :ev, :te, :to)
    HttpLatencies = Struct.new(:sp, :se, :im, :ic, :ev, :te, :to)

    # e: type, d: data, tL timestamp
    StreamingEvent = Struct.new(:e, :d, :t)

    # sp: splits, se: segmentos, im: impressions, ev: events, t: telemetry
    Rates = Struct.new(:sp, :se, :im, :ev, :te)

    # s: sdkUrl, e: eventsUrl, a: authUrl, st: streamUrl, t: telemetryUrl
    UrlOverrides = Struct.new(:s, :e, :a, :st, :t)

    # om: operationMode, se: streamingEnabled, st: storage, rr: refreshRate, uo: urlOverrides, iq: impressionsQueueSize,
    # eq: eventsQueueSize, im: impressionsMode, il: impressionListenerEnabled, hp: httpProxyDetected, af: activeFactories,
    # rf: redundantActiveFactories, tr: timeUntilSdkReady, bt: burTimeouts, nr: sdkNotReadyUsage, t: tags, i: integrations
    ConfigInit = Struct.new(:om, :st, :af, :rf, :t, :se, :rr, :uo, :iq, :eq, :im, :il, :hp, :tr, :bt, :nr, :i)

    # ls: lastSynchronization, ml: clientMethodLatencies, me: clientMethodExceptions, he: httpErros, hl: httpLatencies,
    # tr: tokenRefreshes, ar: authRejections, iq: impressionsQueued, ide: impressionsDeduped, idr: impressionsDropped,
    # spc: splitsCount, sec: segmentCount, skc: segmentKeyCount, sl: sessionLengthMs, eq: eventsQueued, ed: eventsDropped,
    # se: streamingEvents, t: tags
    Usage = Struct.new(:ls, :ml, :me, :he, :hl, :tr, :ar, :iq, :ide, :idr, :spc, :sec, :skc, :sl, :eq, :ed, :se, :t)

    # t: treatment, ts: treatments, tc: treatmentWithConfig, tcs: treatmentsWithConfig, tr: track
    ClientMethodLatencies = Struct.new(:t, :ts, :tc, :tcs, :tr)
    ClientMethodExceptions = Struct.new(:t, :ts, :tc, :tcs, :tr)
  end
end
