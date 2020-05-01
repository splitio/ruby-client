module SplitIoClient
  class SplitIoError < StandardError; end

  class SDKShutdownException < SplitIoError; end

  class SDKBlockerTimeoutExpiredException < SplitIoError; end

  class SSEClientException < SplitIoError
    attr_reader :event

    def initialize(event)
      @event = event
    end
  end
end
