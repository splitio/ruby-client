module SplitIoClient
  class SplitIoError < StandardError; end

  # We are deliberatly not inheriting from SplitIoError so that
  # `rescue StandardError` won't catch and prevent shutdown.
  class SDKShutdownException < Exception; end

  class SDKBlockerTimeoutExpiredException < SplitIoError; end

  class SSEClientException < SplitIoError
    attr_reader :event

    def initialize(event)
      @event = event
    end
  end
end
