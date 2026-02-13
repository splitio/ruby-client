# frozen_string_literal: true

module SplitIoClient
  module Engine
    module Events
      class EventsManagerConfig
        attr_accessor :require_all, :prerequisites, :require_any, :suppressed_by, :execution_limits, :evaluation_order

        def initialize
          @require_all = construct_require_all
          @prerequisites = construct_prerequisites
          @require_any = construct_require_any
          @suppressed_by = construct_suppressed_by
          @execution_limits = construct_execution_limits
          @evaluation_order = construct_sorted_events
        end

        private

        def construct_require_all
          {
            SplitIoClient::Engine::Models::SdkEvent::SDK_READY => Set.new([SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY])
          }
        end

        def construct_prerequisites
          {
            SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE => Set.new([SplitIoClient::Engine::Models::SdkEvent::SDK_READY])
          }
        end

        def construct_require_any
          {
            SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE => Set.new(
              [
                SplitIoClient::Engine::Models::SdkInternalEvent::FLAG_KILLED_NOTIFICATION,
                SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED,
                SplitIoClient::Engine::Models::SdkInternalEvent::RB_SEGMENTS_UPDATED,
                SplitIoClient::Engine::Models::SdkInternalEvent::SEGMENTS_UPDATED
              ]
            )
          }
        end

        def construct_suppressed_by
          {}
        end

        def construct_execution_limits
          {
            SplitIoClient::Engine::Models::SdkEvent::SDK_READY => 1,
            SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE => -1
          }
        end

        def construct_sorted_events
          sorted_events = []
          [SplitIoClient::Engine::Models::SdkEvent::SDK_READY, SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE].each do |sdk_event|
            sorted_events = dfs_recursive(sdk_event, sorted_events)
          end

          sorted_events
        end

        def dfs_recursive(sdk_event, added)
          return added if added.include?(sdk_event)

          get_dependencies(sdk_event).each do |dependent_event|
            added = dfs_recursive(dependent_event, added)
          end

          added.push(sdk_event)

          added
        end

        def get_dependencies(sdk_event)
          dependencies = Set.new
          @prerequisites.each do |prerequisites_event_name, prerequisites_event_value|
            next unless prerequisites_event_name == sdk_event

            prerequisites_event_value.each do |prereq_event|
              dependencies.add(prereq_event)
            end
          end

          @suppressed_by.each do |suppressed_event_name, suppressed_event_value|
            dependencies.add(suppressed_event_name) if suppressed_event_value.include?(sdk_event)
          end

          dependencies
        end
      end
    end
  end
end
