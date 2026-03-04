# frozen_string_literal: false

module SplitIoClient
  module Engine::Models
    class ValidSdkEvent
      attr_reader :sdk_event, :valid

      def initialize(sdk_event, valid)
        @sdk_event = sdk_event
        @valid = valid
      end
    end
  end
end
