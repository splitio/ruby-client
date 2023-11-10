module SplitIoClient
  module Engine
    module Parser
      class Evaluator
        def initialize(segments_repository, splits_repository, config)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @config = config
          @cache = {}
        end

        def evaluate_feature_flag(keys, feature_flag, attributes = nil)
          # DependencyMatcher here, split is actually a split_name in this case
          cache_result = feature_flag.is_a? String
          evaluate_treatment(keys, feature_flag, cache_result, attributes)
        end

        def evaluate_feature_flags(keys, feature_flag_names, attributes = nil, calling_method)
          # DependencyMatcher here, split is actually a split_name in this case
          feature_flags = @splits_repository.splits(feature_flag_names)
          treatments = Hash.new
          invalid_treatments = Hash.new
          feature_flags.each do |key, feature_flag|
            if feature_flag.nil?
              @config.logger.warn("#{calling_method}: you passed #{key} that " \
                'does not exist in this environment, please double check what feature flags exist in the Split user interface')
                invalid_treatments[key] = {
                  treatment: "control",
                  config: nil,
                  label: Engine::Models::Label::NOT_FOUND
                }
                next
            end

            treatments[key] = evaluate_treatment(keys, feature_flag, feature_flag[:name], attributes)
          end
          treatments.merge(invalid_treatments)
        end

        private

        def evaluate_treatment(keys, feature_flag, cache_result, attributes)
          digest = Digest::MD5.hexdigest("#{{matching_key: keys[:matching_key]}}#{feature_flag}#{attributes}")
          if Models::Split.archived?(feature_flag)
            return treatment_hash(Models::Label::ARCHIVED, Models::Treatment::CONTROL, feature_flag[:changeNumber])
          end

          treatment = if Models::Split.matchable?(feature_flag)
            match(feature_flag, keys, attributes)
          else
            treatment_hash(Models::Label::KILLED, feature_flag[:defaultTreatment], feature_flag[:changeNumber], split_configurations(feature_flag[:defaultTreatment], feature_flag))
          end

          @cache[digest] = treatment if cache_result

          treatment
        end

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
