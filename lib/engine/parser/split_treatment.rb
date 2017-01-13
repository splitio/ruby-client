module SplitIoClient
  module Engine
    module Parser
      class SplitTreatment
        def initialize(segments_repository)
          @segments_repository = segments_repository
        end

        def call(keys, split, attributes = nil)
          split_model = Models::Split.new(split)
          @default_treatment = split[:defaultTreatment]

          return treatment(Models::Label::ARCHIVED, Treatments::CONTROL, split[:changeNumber]) if split_model.archived?

          if split_model.matchable?
            match(split, keys, attributes)
          else
            treatment(Models::Label::KILLED, @default_treatment, split[:changeNumber])
          end
        end

        private

        def match(split, keys, attributes)
          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c)

            next if condition.empty?

            if matcher_type(condition).match?(keys[:matching_key], attributes)
              key = keys[:bucketing_key] ? keys[:bucketing_key] : keys[:matching_key]
              result = Splitter.get_treatment(key, split[:seed], condition.partitions)

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
              matchers << condition.send(
                "matcher_#{matcher[:matcherType].downcase}",
                matcher: matcher, segments_repository: @segments_repository
              )
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
      end
    end
  end
end
