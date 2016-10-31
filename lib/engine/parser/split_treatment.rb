module SplitIoClient
  module Engine
    module Parser
      class SplitTreatment
        def initialize(segments_repository)
          @segments_repository = segments_repository
        end

        def call(keys, split, attributes = nil)
          split_model = Models::Split.new(split)
          default_treatment = split[:defaultTreatment]

          return Treatments::CONTROL if split_model.archived?

          split_model.matchable? ? match(split, keys, attributes, default_treatment) : default_treatment
        end

        private

        def match(split, keys, attributes, default_treatment)
          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c)

            next if condition.empty?

            if matcher_type(condition).match?(keys[:matching_key], attributes)
              treatment = Splitter.get_treatment(keys[:bucketing_key], split[:seed], condition.partitions)

              return treatment.nil? ? default_treatment : treatment
            end
          end

          default_treatment
        end

        def matcher_type(condition)
          matchers = []

          condition.matchers.each do |matcher|
            matchers << condition.send(
              "matcher_#{matcher[:matcherType].downcase}",
              matcher: matcher, segments_repository: @segments_repository
            )
          end

          final_matcher = condition.create_condition_matcher(matchers)

          if final_matcher.nil?
            @logger.error('Invalid matcher type')
          else
            final_matcher
          end
        end
      end
    end
  end
end
