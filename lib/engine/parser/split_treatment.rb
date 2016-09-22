module SplitIoClient
  module Engine
    module Parser
      class SplitTreatment
        def initialize(splits_repository, segments_repository, logger)
          @splits_repository = splits_repository
          @segments_repository = segments_repository
          @logger = logger
        end

        def call(key, split_name, default_treatment, attributes = nil)
          split = @splits_repository.get_split(split_name)

          return treatment_hash(key, Treatments::CONTROL) if archived?(split)

          matchable?(split) ? match(split, key, attributes, default_treatment) : treatment_hash(key, default_treatment)
        end

        private

        def match(split, key, attributes, default_treatment)
          split[:conditions].each do |c|
            condition = SplitIoClient::Condition.new(c)

            next if condition.empty?

            matcher = matcher_type(condition)

            if matcher.match?(key, attributes)
              treatment = Splitter.get_treatment(key, split[:seed], condition.partitions)
              treatment = treatment.nil? ? default_treatment : treatment

              return treatment_hash(key, treatment, matcher, condition.partitions.map(&:data))
            end
          end

          treatment_hash(key, default_treatment)
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

        def label(key, treatment, matcher = nil, partitions = nil)
          if matcher && partitions
            matched_partition = partitions.find { |p| p[:treatment] == treatment }

            "if #{key} #{matcher.to_s} then match #{matched_partition[:size]}%:#{treatment}"
          else
            "if #{key} then match to #{treatment}"
          end
        end

        def treatment_hash(key, treatment, matcher = nil, partitions = nil)
          {
            label: label(key, treatment, matcher, partitions),
            treatment: treatment
          }
        end
      end
    end
  end
end
