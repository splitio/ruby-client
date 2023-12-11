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

  class ApiException < SplitIoError
    def initialize(msg, exception_code)
      @@exception_code = exception_code
      super(msg)
    end
    def exception_code
      @@exception_code
    end
  end

end
