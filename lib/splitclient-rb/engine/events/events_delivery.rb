# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Events
      class EventsDelivery
        def initialize(config)
          @config = config
        end

        def deliver(sdk_event, event_metadata, event_handler)
          event_handler.call(event_metadata)
        rescue StandardError => e
          @config.logger.error("Exception when calling handler for Sdk Event #{sdk_event}")
          @config.log_found_exception(__method__.to_s, e)
        end
      end
    end
  end
end
