module SplitIoClient
  module Engine
    module Parser
      class SplitTreatment
        def initialize(segments_repository, splits_repository)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
        end

        def call(keys, split, attributes = nil)
          # DependencyMatcher here, split is actually a split_name in this case
          # TODO: Cache splits in case of DependencyMatcher
          split = @splits_repository.get_split(split) if split.is_a? String

          @default_treatment = split[:defaultTreatment]

          if Models::Split.archived?(split)
            return treatment(Models::Label::ARCHIVED, Treatments::CONTROL, split[:changeNumber])
          end

          if Models::Split.matchable?(split)
            match(split, keys, attributes)
          else
            treatment(Models::Label::KILLED, @default_treatment, split[:changeNumber])
          end
        end

        private

        def match(split, keys, attributes)
          in_rollout = false
          key = keys[:bucketing_key] ? keys[:bucketing_key] : keys[:matching_key]
          legacy_algo = (split[:algo] == 1 || split[:algo] == nil) ? true : false

          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c)

            next if condition.empty?

            if !in_rollout && condition.type == SplitIoClient::Condition::TYPE_ROLLOUT
              if split[:trafficAllocation] < 100
                bucket = Splitter.bucket(Splitter.count_hash(key, split[:trafficAllocationSeed].to_i, legacy_algo))

                if bucket >= split[:trafficAllocation]
                  return treatment(Models::Label::NOT_IN_SPLIT, @default_treatment, split[:changeNumber])
                end
              end

              in_rollout = true
            end

            if matcher_type(condition).match?(keys[:matching_key], self, attributes)
              key = keys[:bucketing_key] ? keys[:bucketing_key] : keys[:matching_key]
              result = Splitter.get_treatment(key, split[:seed], condition.partitions, split[:algo])

              if result.nil?
                return treatment(Models::Label::NO_RULE_MATCHED, @default_treatment, split[:changeNumber])
              else
                return treatment(c[:label], result, split[:changeNumber])
              end
            end
          end

          treatment(Models::Label::NO_RULE_MATCHED, @default_treatment, split[:changeNumber])
        end

        def matcher_type(condition)
          matchers = []

          @segments_repository.adapter.pipelined do
            condition.matchers.each do |matcher|
              matchers << if matcher[:negate]
                condition.negation_matcher(matcher_instance(matcher[:matcherType], condition, matcher))
              else
                matcher_instance(matcher[:matcherType], condition, matcher)
              end
            end
          end

          final_matcher = condition.create_condition_matcher(matchers)

          if final_matcher.nil?
            @logger.error('Invalid matcher type')
          else
            final_matcher
          end
        end

        def treatment(label, treatment, change_number = nil)
          { label: label, treatment: treatment, change_number: change_number }
        end

        def matcher_instance(type, condition, matcher)
          condition.send(
            "matcher_#{type.downcase}",
            matcher: matcher, segments_repository: @segments_repository
          )
        end
      end
    end
  end
end
