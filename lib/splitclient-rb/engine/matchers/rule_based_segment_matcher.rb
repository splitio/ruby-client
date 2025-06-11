# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the user defined matcher
  #
  class RuleBasedSegmentMatcher < Matcher
    MATCHER_TYPE = 'IN_RULE_BASED_SEGMENT'

    def initialize(segments_repository, rule_based_segments_repository, segment_name, config)
      super(config.logger)
      @rule_based_segments_repository = rule_based_segments_repository
      @segments_repository = segments_repository
      @segment_name = segment_name
      @config = config
    end

    #
    # evaluates if the key matches the matcher
    #
    # @param key [string] key value to be matched
    #
    # @return [boolean] evaluation of the key against the segment
    def match?(args)
      rule_based_segment = @rule_based_segments_repository.get_rule_based_segment(@segment_name)
      return false if rule_based_segment.nil?

      key = update_key(args)
      return false if rule_based_segment[:excluded][:keys].include?(key)

      return false unless check_excluded_segments(rule_based_segment, key, args)

      matches = false
      rule_based_segment[:conditions].each do |c|
        condition = SplitIoClient::Condition.new(c, @config)
        next if condition.empty?

        matches = Helpers::EvaluatorHelper.matcher_type(condition, @segments_repository, @rule_based_segments_repository).match?(args)
      end
      @logger.debug("[InRuleSegmentMatcher] #{@segment_name} is in rule based segment -> #{matches}")
      matches
    end

    private

    def check_excluded_segments(rule_based_segment, key, args)
      rule_based_segment[:excluded][:segments].each do |segment|
        if segment[:type] == SplitIoClient::Engine::Models::SegmentType::STANDARD &&
           @segments_repository.in_segment?(segment[:name], key)
          return false
        end
        return false if segment[:type] == SplitIoClient::Engine::Models::SegmentType::RULE_BASED_SEGMENT && match_rbs(
          @rule_based_segments_repository.get_rule_based_segment(segment[:name]), args
        )
      end
      true
    end

    def update_key(args)
      if args[:value].nil? || args[:value].empty?
        args[:matching_key]
      else
        args[:value]
      end
    end

    def match_rbs(rule_based_segment, args)
      rbs_matcher = RuleBasedSegmentMatcher.new(@segments_repository, @rule_based_segments_repository,
                                                rule_based_segment[:name], @config)
      rbs_matcher.match?(matching_key: args[:matching_key],
                         bucketing_key: args[:value],
                         attributes: args[:attributes])
    end
  end
end
