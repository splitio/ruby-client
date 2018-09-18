module SplitIoClient
  class SplitIoError < StandardError; end

  class ImpressionShutdownException < SplitIoError; end

  class SDKBlockerTimeoutExpiredException < SplitIoError; end
end
