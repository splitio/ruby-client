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

          return treatment('archived', Treatments::CONTROL) if split_model.archived?

          if split_model.matchable?
            match(split, keys, attributes)
          else
            treatment('killed', @default_treatment)
          end
        end

        private

        def match(split, keys, attributes)
          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c)
            label = c[:label]

            next if condition.empty?

            if matcher_type(condition).match?(keys[:matching_key], attributes)
              result = Splitter.get_treatment(keys[:bucketing_key], split[:seed], condition.partitions)

              if result.nil?
                return treatment('no rule matched', @default_treatment)
              else
                return treatment(label, result)
              end
            end
          end

          treatment('no rule matched', @default_treatment)
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

        def treatment(label, treatment)
          { label: label, treatment: treatment }
        end
      end
    end
  end
end
