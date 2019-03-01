module SplitIoClient
  class SplitIoError < StandardError; end

  class SDKShutdownException < SplitIoError; end

  class SDKBlockerTimeoutExpiredException < SplitIoError; end
end
