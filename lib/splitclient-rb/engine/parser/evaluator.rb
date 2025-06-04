module SplitIoClient
  module Engine
    module Parser
      class Evaluator
        def initialize(segments_repository, splits_repository, rb_segment_repository, config)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @rb_segment_repository = rb_segment_repository
          @config = config
        end

        def evaluate_feature_flag(keys, feature_flag, attributes = nil)
          # DependencyMatcher here, split is actually a split_name in this case
          cache_result = feature_flag.is_a? String
          feature_flag = @splits_repository.get_split(feature_flag) if cache_result
          evaluate_treatment(keys, feature_flag, attributes)
        end

        private

        def evaluate_treatment(keys, feature_flag, attributes)
          if Models::Split.archived?(feature_flag)
            return treatment_hash(Models::Label::ARCHIVED, Models::Treatment::CONTROL, feature_flag[:changeNumber])
          end

          treatment = if Models::Split.matchable?(feature_flag)
                        match(feature_flag, keys, attributes)
                      else
                        treatment_hash(Models::Label::KILLED, feature_flag[:defaultTreatment], feature_flag[:changeNumber], split_configurations(feature_flag[:defaultTreatment], feature_flag))
                      end

          treatment
        end

        def split_configurations(treatment, split)
          return nil if split[:configurations].nil?
          split[:configurations][treatment.to_sym]
        end

        def match(split, keys, attributes)
          prerequisites_matcher = SplitIoClient::PrerequisitesMatcher.new(split[:prerequisites], @config.split_logger)
          return treatment_hash(Models::Label::PREREQUISITES_NOT_MET, split[:defaultTreatment], split[:changeNumber], split_configurations(split[:defaultTreatment], split)) unless prerequisites_matcher.match?(
              matching_key: keys[:matching_key],
              bucketing_key: keys[:bucketing_key],
              evaluator: self,
              attributes: attributes
            )

          in_rollout = false
          key = keys[:bucketing_key] ? keys[:bucketing_key] : keys[:matching_key]
          legacy_algo = (split[:algo] == 1 || split[:algo] == nil) ? true : false
          splitter = Splitter.new

          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c, @config)

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
            condition_matched = Helpers::EvaluatorHelper::matcher_type(condition, @segments_repository, @rb_segment_repository).match?(
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

        def treatment_hash(label, treatment, change_number = nil, configurations = nil)
          { label: label, treatment: treatment, change_number: change_number, config: configurations }
        end
      end
    end
  end
end
