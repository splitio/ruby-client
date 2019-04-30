module SplitIoClient
  module Engine
    module Parser
      class Evaluator
        def initialize(segments_repository, splits_repository, multiple = false)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @multiple = multiple
          @cache = {}
        end

        def call(keys, split, attributes = nil)
          # DependencyMatcher here, split is actually a split_name in this case
          cache_result = split.is_a? String
          split = @splits_repository.get_split(split) if cache_result
          digest = Digest::MD5.hexdigest("#{{matching_key: keys[:matching_key]}}#{split}#{attributes}")

          if Models::Split.archived?(split)
            return treatment_hash(Models::Label::ARCHIVED, Models::Treatment::CONTROL, split[:changeNumber])
          end

          treatment = if Models::Split.matchable?(split)
            if @multiple && @cache[digest]
              @cache[digest]
            else
              match(split, keys, attributes)
            end
          else
            treatment_hash(Models::Label::KILLED, split[:defaultTreatment], split[:changeNumber], split_configurations(split[:defaultTreatment], split))
          end

          @cache[digest] = treatment if cache_result

          treatment
        end

        private

        def split_configurations(treatment, split)
          return nil if split[:configurations].nil?
          split[:configurations][treatment.to_sym]
        end

        def match(split, keys, attributes)
          in_rollout = false
          key = keys[:bucketing_key] ? keys[:bucketing_key] : keys[:matching_key]
          legacy_algo = (split[:algo] == 1 || split[:algo] == nil) ? true : false
          splitter = Splitter.new

          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c)

            next if condition.empty?

            if !in_rollout && condition.type == SplitIoClient::Condition::TYPE_ROLLOUT
              if split[:trafficAllocation] < 100
                bucket = splitter.bucket(splitter.count_hash(key, split[:trafficAllocationSeed].to_i, legacy_algo))

                if bucket > split[:trafficAllocation]
                  return treatment_hash(Models::Label::NOT_IN_SPLIT, split[:defaultTreatment], split[:changeNumber], split_configurations(split[:defaultTreatment], split))
                end
              end

              in_rollout = true
            end

            condition_matched = matcher_type(condition).match?(
              matching_key: keys[:matching_key],
              bucketing_key: keys[:bucketing_key],
              evaluator: self,
              attributes: attributes
            )

            next unless condition_matched

            result = splitter.get_treatment(key, split[:seed], condition.partitions, split[:algo])

            if result.nil?
              return treatment_hash(Models::Label::NO_RULE_MATCHED, split[:defaultTreatment], split[:changeNumber], split_configurations(split[:defaultTreatment], split))
            else
              return treatment_hash(c[:label], result, split[:changeNumber],split_configurations(result, split))
            end
          end

          treatment_hash(Models::Label::NO_RULE_MATCHED, split[:defaultTreatment], split[:changeNumber], split_configurations(split[:defaultTreatment], split))
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

        def treatment_hash(label, treatment, change_number = nil, configurations = nil)
          { label: label, treatment: treatment, change_number: change_number, config: configurations }
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
