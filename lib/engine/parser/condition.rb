module SplitIoClient
  #
  # acts as dto for a condition structure
  #
  class Condition < NoMethodError
    TYPE_ROLLOUT = 'ROLLOUT'.freeze
    TYPE_WHITELIST = 'WHITELIST'.freeze
    #
    # definition of the condition
    #
    # @returns [object] condition values
    attr_accessor :data

    def initialize(condition)
      @data = condition
      @partitions = set_partitions
    end

    def create_condition_matcher(matchers)
      CombiningMatcher.new(combiner, matchers) unless combiner.nil?
    end

    #
    # @return [object] the combiner value for this condition
    def combiner
      @data[:matcherGroup][:combiner]
    end

    #
    # @return [object] the matcher value for this condition
    def matcher
      @data[:matcherGroup][:matchers].first[:matcherType]
    end

    #
    # @return [object] the matchers array value for this condition
    def matchers
      @data[:matcherGroup][:matchers]
    end

    #
    # @return [string] condition type
    def type
      @data[:conditionType]
    end

    def negation_matcher(matcher)
      NegationMatcher.new(matcher)
    end

    def matcher_all_keys(_params)
      @matcher_all_keys ||= AllKeysMatcher.new
    end

    # returns UserDefinedSegmentMatcher[object]
    def matcher_in_segment(params)
      matcher = params[:matcher]
      segment_name = matcher[:userDefinedSegmentMatcherData] && matcher[:userDefinedSegmentMatcherData][:segmentName]

      UserDefinedSegmentMatcher.new(params[:segments_repository], segment_name)
    end

    # returns WhitelistMatcher[object] the whitelist for this condition in case it has a whitelist matcher
    def matcher_whitelist(params)
      result = nil
      matcher = params[:matcher]
      is_user_whitelist = ((matcher[:keySelector]).nil? || (matcher[:keySelector])[:attribute].nil?)
      if is_user_whitelist
        result = (matcher[:whitelistMatcherData])[:whitelist]
      else
        attribute = (matcher[:keySelector])[:attribute]
        white_list = (matcher[:whitelistMatcherData])[:whitelist]
        result =  { attribute: attribute, value: white_list }
      end
      WhitelistMatcher.new(result)
    end

    def matcher_equal_to(params)
      matcher = params[:matcher]
      attribute = (matcher[:keySelector])[:attribute]
      value = (matcher[:unaryNumericMatcherData])[:value]
      data_type = (matcher[:unaryNumericMatcherData])[:dataType]
      EqualToMatcher.new(attribute: attribute, value: value, data_type: data_type)
    end

    def matcher_greater_than_or_equal_to(params)
      matcher = params[:matcher]
      attribute = (matcher[:keySelector])[:attribute]
      value = (matcher[:unaryNumericMatcherData])[:value]
      data_type = (matcher[:unaryNumericMatcherData])[:dataType]
      GreaterThanOrEqualToMatcher.new(attribute: attribute, value: value, data_type: data_type)
    end

    def matcher_less_than_or_equal_to(params)
      matcher = params[:matcher]
      attribute = (matcher[:keySelector])[:attribute]
      value = (matcher[:unaryNumericMatcherData])[:value]
      data_type = (matcher[:unaryNumericMatcherData])[:dataType]
      LessThanOrEqualToMatcher.new(attribute: attribute, value: value, data_type: data_type)
    end

    def matcher_between(params)
      matcher = params[:matcher]
      attribute = (matcher[:keySelector])[:attribute]
      start_value = (matcher[:betweenMatcherData])[:start]
      end_value = (matcher[:betweenMatcherData])[:end]
      data_type = (matcher[:betweenMatcherData])[:dataType]
      BetweenMatcher.new(attribute: attribute, start_value: start_value, end_value: end_value, data_type: data_type)
    end

    def matcher_equal_to_set(params)
      EqualToSetMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    def matcher_contains_any_of_set(params)
      ContainsAnyMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    def matcher_contains_all_of_set(params)
      ContainsAllMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    def matcher_part_of_set(params)
      PartOfSetMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    def matcher_starts_with(params)
      StartsWithMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    def matcher_ends_with(params)
      EndsWithMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    def matcher_contains_string(params)
      ContainsMatcher.new(
        params[:matcher][:keySelector][:attribute],
        params[:matcher][:whitelistMatcherData][:whitelist]
      )
    end

    #
    # @return [object] the negate value for this condition
    def negate
      @data[:matcherGroup][:matchers].first[:negate]
    end

    #
    # @return [object] the array of partitions for this condition
    attr_reader :partitions

    #
    # converts the partitions hash for this condition into an array of partition objects
    #
    # @return [void]
    def set_partitions
      partitions_list = []
      @data[:partitions].each do |p|
        partition = SplitIoClient::Partition.new(p)
        partitions_list << partition
      end
      partitions_list
    end

    #
    # @return [boolean] true if the condition is empty false otherwise
    def empty?
      @data.empty?
    end
  end
end
