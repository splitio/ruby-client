# frozen_string_literal: false

module SplitIoClient
  module Engine::Models
    class SdkInternalEventNotification
      attr_reader :internal_event, :metadata

      def initialize(internal_event, metadata)
        @internal_event = internal_event
        @metadata = metadata
      end
    end
  end
end
