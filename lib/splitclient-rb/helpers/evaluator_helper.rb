# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class EvaluatorHelper
      def self.matcher_type(condition, segments_repository, rb_segment_repository)
        matchers = []
        segments_repository.adapter.pipelined do
          condition.matchers.each do |matcher|
            matchers << if matcher[:negate]
                          condition.negation_matcher(matcher_instance(matcher[:matcherType], condition, matcher))
                        else
                          matcher_instance(matcher[:matcherType], condition, matcher, segments_repository, rb_segment_repository)
                        end
          end
        end
        final_matcher = condition.create_condition_matcher(matchers)

        if final_matcher.nil?
          config.logger.error('Invalid matcher type')
        else
          final_matcher
        end
        final_matcher
      end

      def self.matcher_instance(type, condition, matcher, segments_repository, rb_segment_repository)
        condition.send(
          "matcher_#{type.downcase}",
          matcher: matcher, segments_repository: segments_repository, rule_based_segments_repository: rb_segment_repository
        )
      end
    end
  end
end
