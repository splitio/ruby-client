require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class RuleBasedSegmentsRepository < Repository
        attr_reader :adapter
        DEFAULT_CONDITIONS_TEMPLATE = [{
          conditionType: "ROLLOUT",
          matcherGroup: {
              combiner: "AND",
              matchers: [
              {
                  keySelector: nil,
                  matcherType: "ALL_KEYS",
                  negate: false,
                  userDefinedSegmentMatcherData: nil,
                  whitelistMatcherData: nil,
                  unaryNumericMatcherData: nil,
                  betweenMatcherData: nil,
                  dependencyMatcherData: nil,
                  booleanMatcherData: nil,
                  stringMatcherData: nil
              }]
          }
        }]
        TILL_PREFIX = '.rbsegments.till'
        RB_SEGMENTS_PREFIX = '.rbsegment.'
        REGISTERED_PREFIX = '.segments.registered'

        def initialize(config)
          super(config)
          @adapter = case @config.cache_adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            SplitIoClient::Cache::Adapters::CacheAdapter.new(@config)
          else
            @config.cache_adapter
          end
          unless @config.mode.equal?(:consumer)
            @adapter.set_string(namespace_key(TILL_PREFIX), '-1')
            @adapter.initialize_map(namespace_key(REGISTERED_PREFIX))
          end
        end

        def update(to_add, to_delete, new_change_number)
          to_add.each{ |rule_based_segment| add_rule_based_segment(rule_based_segment) }
          to_delete.each{ |rule_based_segment| remove_rule_based_segment(rule_based_segment) }
          set_change_number(new_change_number)
        end

        def get_rule_based_segment(name)
          rule_based_segment = @adapter.string(namespace_key("#{RB_SEGMENTS_PREFIX}#{name}"))

          JSON.parse(rule_based_segment, symbolize_names: true) if rule_based_segment
        end

        def rule_based_segment_names
          @adapter.find_strings_by_prefix(namespace_key(RB_SEGMENTS_PREFIX))
            .map { |rule_based_segment_names| rule_based_segment_names.gsub(namespace_key(RB_SEGMENTS_PREFIX), '') }
        end

        def set_change_number(since)
          @adapter.set_string(namespace_key(TILL_PREFIX), since)
        end

        def get_change_number
          @adapter.string(namespace_key(TILL_PREFIX))
        end

        def set_segment_names(names)
          return if names.nil? || names.empty?

          names.each do |name|
            @adapter.add_to_set(namespace_key(REGISTERED_PREFIX), name)
          end
        end

        def exists?(name)
          @adapter.exists?(namespace_key("#{RB_SEGMENTS_PREFIX}#{name}"))
        end

        def clear
          @adapter.clear(namespace_key)
        end

        def contains?(segment_names)
          return false if rule_based_segment_names.empty?
          return Set.new(segment_names).subset?(rule_based_segment_names)
        end

        private

        def add_rule_based_segment(rule_based_segment)
          return unless rule_based_segment[:name]

          if check_undefined_matcher(rule_based_segment)
            @config.logger.warn("Rule based segment #{rule_based_segment[:name]} has undefined matcher, setting conditions to default template.")
            rule_based_segment[:conditions] = RuleBasedSegmentsRepository::DEFAULT_CONDITIONS_TEMPLATE
          end

          @adapter.set_string(namespace_key("#{RB_SEGMENTS_PREFIX}#{rule_based_segment[:name]}"), rule_based_segment.to_json)
        end

        def check_undefined_matcher(rule_based_segment)
          for condition in rule_based_segment[:conditions]
            for matcher in condition[:matcherGroup][:matchers]
              if !SplitIoClient::Condition.instance_methods(false).map(&:to_s).include?("matcher_#{matcher[:matcherType].downcase}")
                @config.logger.error("Detected undefined matcher #{matcher[:matcherType].downcase} in feature flag #{rule_based_segment[:name]}")
                return true
              end
            end
          end
          return false
        end

        def remove_rule_based_segment(rule_based_segment)
          @adapter.delete(namespace_key("#{RB_SEGMENTS_PREFIX}#{rule_based_segment[:name]}"))
        end
      end
    end
  end
end
