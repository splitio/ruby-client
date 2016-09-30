module SplitIoClient
  module Engine
    module Parser
      class SplitTreatment
        def initialize(splits_repository, segments_repository)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
        end

        def call(keys, split_name, default_treatment, attributes = nil)
          split = @splits_repository.get_split(split_name)

          return Treatments::CONTROL if archived?(split)

          matchable?(split) ? match(split, keys, attributes, default_treatment) : default_treatment
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

        def matchable?(split)
          !split.nil? && split[:status] == 'ACTIVE' && split[:killed] == false
        end

        def archived?(split)
          !split.nil? && split[:status] == 'ARCHIVED'
        end
      end
    end
  end
end
