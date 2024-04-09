# frozen_string_literal: true

module SplitIoClient
  module Api
    class RequestContext
      def initialize(headers)
        @headers = headers
      end

      def headers
        @headers
      end
    end
  end
end
