# frozen_string_literal: true

module SplitIoClient
  #
  # class to implement the user defined matcher
  #
  class RuleBasedSegmentMatcher < Matcher
    MATCHER_TYPE = 'IN_RULE_BASED_SEGMENT'

    def initialize(rule_based_segments_repository, segments_repository, segment_name, config, evaluator)
      super(config.logger)
      @rule_based_segments_repository = rule_based_segments_repository
      @segments_repository = segments_repository
      @segment_name = segment_name
      @evaluator = evaluator
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

      return false if rule_based_segment[:excluded][:keys].include?([args[:value]])

      return false if @segments_repository.contains?(rule_based_segment[:excluded][:segments])

      matches = false
      rule_based_segment[:conditions].each do |c|
        condition = SplitIoClient::Condition.new(c, @config)
        next if condition.empty?

        matches = Helpers::EvaluatorHelper.matcher_type(condition, @segments_repository).match?(args)
      end
      @logger.debug("[InRuleSegmentMatcher] #{@segment_name} is in rule based segment -> #{matches}")

      matches
    end
  end
end
