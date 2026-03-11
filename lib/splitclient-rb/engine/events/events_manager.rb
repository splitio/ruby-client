# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Events
      class EventsManager
        include SplitIoClient::Engine::Models

        def initialize(events_manager_config, events_delivery, config)
          @manager_config = events_manager_config
          @events_delivery = events_delivery
          @active_subscriptions = {}
          @internal_events_status = {}
          @mutex = Mutex.new
          @config = config
        end

        def register(sdk_event, event_handler)
          return if @active_subscriptions.key?(sdk_event) && !get_event_handler(sdk_event).nil?

          @mutex.synchronize do
            # SDK ready already fired
            if sdk_event == SdkEvent::SDK_READY && event_already_triggered(sdk_event)
              @active_subscriptions[sdk_event] = EventActiveSubscriptions.new(true, event_handler)
              @config.logger.debug('EventsManager: Firing SDK_READY event for new subscription') if @config.debug_enabled
              fire_sdk_event(sdk_event, nil)
              return
            end

            @config.logger.debug("EventsManager: Register event: #{sdk_event}") if @config.debug_enabled
            @active_subscriptions[sdk_event] = EventActiveSubscriptions.new(false, event_handler)
          end
        end

        def unregister(sdk_event)
          return unless @active_subscriptions.key?(sdk_event)

          @mutex.synchronize do
            @active_subscriptions.delete(sdk_event)
          end
        end

        def notify_internal_event(sdk_internal_event, event_metadata)
          @mutex.synchronize do
            update_internal_event_status(sdk_internal_event, true)
            @manager_config.evaluation_order.each do |sorted_event|
              if get_sdk_event_if_applicable(sdk_internal_event).include?(sorted_event) &&
                 !get_event_handler(sorted_event).nil?
                fire_sdk_event(sorted_event, event_metadata)
              end

              # if client is not subscribed to SDK_READY
              if check_if_register_needed(sorted_event)
                @config.logger.debug('EventsManager: Registering SDK_READY event as fired') if @config.debug_enabled
                @active_subscriptions[SdkEvent::SDK_READY] = EventActiveSubscriptions.new(true, nil)
              end
            end
          end
        end

        def destroy
          @mutex.synchronize do
            @active_subscriptions = {}
            @internal_events_status = {}
          end
        end

        private

        def check_if_register_needed(sorted_event)
          sorted_event == SdkEvent::SDK_READY &&
            get_event_handler(sorted_event).nil? &&
            !@active_subscriptions.include?(sorted_event)
        end

        def fire_sdk_event(sdk_event, event_metadata)
          @config.logger.debug("EventsManager: Firing Sdk event: #{sdk_event}") if @config.debug_enabled
          @config.threads[:sdk_event_notify] = Thread.new do
            @events_delivery.deliver(sdk_event, event_metadata, get_event_handler(sdk_event))
          end
          sdk_event_triggered(sdk_event)
        end

        def event_already_triggered(sdk_event)
          return @active_subscriptions[sdk_event].triggered if @active_subscriptions.key?(sdk_event)

          false
        end

        def get_internal_event_status(sdk_internal_event)
          return @internal_events_status[sdk_internal_event] if @internal_events_status.key?(sdk_internal_event)

          false
        end

        def update_internal_event_status(sdk_internal_event, status)
          @internal_events_status[sdk_internal_event] = status
        end

        def sdk_event_triggered(sdk_event)
          return unless @active_subscriptions.key?(sdk_event)

          return if @active_subscriptions[sdk_event].triggered

          @active_subscriptions[sdk_event].triggered = true
        end

        def get_event_handler(sdk_event)
          return nil unless @active_subscriptions.key?(sdk_event)

          @active_subscriptions[sdk_event].handler
        end

        def get_sdk_event_if_applicable(sdk_internal_event)
          final_sdk_event = ValidSdkEvent.new(nil, false)

          events_to_fire = []
          require_any_sdk_event = check_require_any(sdk_internal_event)
          if require_any_sdk_event.valid
            if (!event_already_triggered(require_any_sdk_event.sdk_event) &&
               execution_limit(require_any_sdk_event.sdk_event) == 1) ||
               execution_limit(require_any_sdk_event.sdk_event) == -1
              final_sdk_event = ValidSdkEvent.new(
                require_any_sdk_event.sdk_event,
                check_prerequisites(require_any_sdk_event.sdk_event) &&
                check_suppressed_by(require_any_sdk_event.sdk_event)
              )
            end
            events_to_fire.push(final_sdk_event.sdk_event) if final_sdk_event.valid
          end
          check_require_all.each { |sdk_event| events_to_fire.push(sdk_event) }

          events_to_fire
        end

        def check_require_all
          events = []
          @manager_config.require_all.each do |require_name, require_value|
            final_status = true
            require_value.each { |val| final_status &= get_internal_event_status(val) }
            events.push(require_name) if check_event_eligible_conditions(final_status, require_name, require_value)
          end

          events
        end

        def check_event_eligible_conditions(final_status, require_name, require_value)
          final_status &&
            check_prerequisites(require_name) &&
            ((!event_already_triggered(require_name) &&
            execution_limit(require_name) == 1) ||
            execution_limit(require_name) == -1) &&
            require_value.length.positive?
        end

        def check_prerequisites(sdk_event)
          @manager_config.prerequisites.each do |name, value|
            value.each do |val|
              return false if name == sdk_event && !event_already_triggered(val)
            end
          end

          true
        end

        def check_suppressed_by(sdk_event)
          @manager_config.suppressed_by.each do |name, value|
            value.each do |val|
              return false if name == sdk_event && event_already_triggered(val)
            end
          end

          true
        end

        def execution_limit(sdk_event)
          return -1 unless @manager_config.execution_limits.key?(sdk_event)

          @manager_config.execution_limits[sdk_event]
        end

        def check_require_any(sdk_internal_event)
          valid_sdk_event = ValidSdkEvent.new(nil, false)
          @manager_config.require_any.each do |name, val|
            if val.include?(sdk_internal_event)
              valid_sdk_event = ValidSdkEvent.new(name, true)
              return valid_sdk_event
            end
          end

          valid_sdk_event
        end
      end
    end
  end
end
