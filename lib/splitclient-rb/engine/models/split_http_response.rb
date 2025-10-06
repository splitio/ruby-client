module SplitIoClient
  module Engine
    module Models
      class SplitHttpResponse
        attr_accessor :status, :body

        def initialize(status, body, success)
          @status = status
          @body = body
          @success = success
        end

        def success?
          @success
        end
      end
    end
  end
end
