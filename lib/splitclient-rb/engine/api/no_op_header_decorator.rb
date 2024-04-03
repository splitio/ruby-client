# frozen_string_literal: true

module SplitIoClient
  module Api
    class NoOpHeaderDecorator
      def initialize
        true
      end
      def get_header_overrides(request_context)
        {}
      end
    end
  end
end
