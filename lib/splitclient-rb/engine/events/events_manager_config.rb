# frozen_string_literal: true

module SplitIoClient::Engine::Events
    class EventsManagerConfig
        attr_accessor :require_all, :prerequisites, :require_any, :suppressed_by, :execution_limits, :evaluation_order

        def initialize
            @require_all = get_require_all
            @prerequisites = get_prerequisites
            @require_any = get_require_any
            @suppressed_by = get_suppressed_by
            @execution_limits = get_execution_limits
            @evaluation_order = get_sorted_events
        end
                        
        private

        def get_require_all
            return  {
                        SplitIoClient::Engine::Models::SdkEvent::SDK_READY => Set.new([SplitIoClient::Engine::Models::SdkInternalEvent::SDK_READY])
                    }
        end

        def get_prerequisites
            return  {
                        SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE => Set.new([SplitIoClient::Engine::Models::SdkEvent::SDK_READY])
                    }
        end

        def get_require_any
            return  {
                        SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE => Set.new([SplitIoClient::Engine::Models::SdkInternalEvent::FLAG_KILLED_NOTIFICATION, SplitIoClient::Engine::Models::SdkInternalEvent::FLAGS_UPDATED, 
                                                SplitIoClient::Engine::Models::SdkInternalEvent::RB_SEGMENTS_UPDATED, SplitIoClient::Engine::Models::SdkInternalEvent::SEGMENTS_UPDATED])
                    }
        end

        def get_suppressed_by
            return  {}
        end

        def get_execution_limits
            return  {
                        SplitIoClient::Engine::Models::SdkEvent::SDK_READY => 1,
                        SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE => -1
                    }
        end

        def get_sorted_events
            sorted_events = []
            for sdk_event in [SplitIoClient::Engine::Models::SdkEvent::SDK_READY, SplitIoClient::Engine::Models::SdkEvent::SDK_UPDATE]
                sorted_events = dfs_recursive(sdk_event, sorted_events)
            end

            return sorted_events
        end

        def dfs_recursive(sdk_event, added)
            return added if added.include?(sdk_event)

            get_dependencies(sdk_event).each do |dependent_event|
                added = dfs_recursive(dependent_event, added)
            end

            added.push(sdk_event)
            return added
        end

        def get_dependencies(sdk_event)
            dependencies = Set.new
            @prerequisites.each do |prerequisites_event_name, prerequisites_event_value|
                if prerequisites_event_name == sdk_event
                    for prereq_event in prerequisites_event_value
                        dependencies.add(prereq_event)
                    end
                end
            end

            @suppressed_by.each do |suppressed_event_name, suppressed_event_value|
                if suppressed_event_value.include?(sdk_event)
                    dependencies.add(suppressed_event_name)
                end
            end

            return dependencies
        end
    end
end