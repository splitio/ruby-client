module SplitIoClient

  #
  # acts as dto for a condition structure
  #
  class Condition < NoMethodError

    #
    # definition of the condition
    #
    # @returns [object] condition values
    attr_accessor :data

    def initialize(condition)
      @data = condition
      @partitions = set_partitions
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
    # @return [object] the segment for this condition in case it has a segment matcher
    def matcher_segment
      result = nil
      if self.matcher == 'IN_SEGMENT'
        result = (@data[:matcherGroup][:matchers].first[:userDefinedSegmentMatcherData])[:segmentName]
      end
      result
    end

    #
    # @return [object] the whitelist for this condition in case it has a whitelist matcher
    def matcher_whitelist
      result = nil
      if self.matcher == 'WHITELIST'
        is_user_whitelist = ( (@data[:matcherGroup][:matchers].first[:keySelector]).nil? || (@data[:matcherGroup][:matchers].first[:keySelector])[:attribute].nil? )
        #is_attribute_whitelist? = !is_user_whitelist?
        if is_user_whitelist
          result = (@data[:matcherGroup][:matchers].first[:whitelistMatcherData])[:whitelist]
        else
          attribute = (@data[:matcherGroup][:matchers].first[:keySelector])[:attribute]
          white_list = (@data[:matcherGroup][:matchers].first[:whitelistMatcherData])[:whitelist]
          result =  {attribute: attribute, value: white_list}
        end
      end
      result
    end

    def matcher_equal
      result = nil
      if self.matcher == 'EQUAL_TO'
        attribute = (@data[:matcherGroup][:matchers].first[:keySelector])[:attribute]
        value = (@data[:matcherGroup][:matchers].first[:unaryNumericMatcherData])[:value]
        data_type = (@data[:matcherGroup][:matchers].first[:unaryNumericMatcherData])[:dataType]
        result = {attribute: attribute, value: value, data_type: data_type}
      end
      result
    end

    def matcher_greater_than_or_equal
      result = nil
      if self.matcher == 'GREATER_THAN_OR_EQUAL_TO'
        attribute = (@data[:matcherGroup][:matchers].first[:keySelector])[:attribute]
        value = (@data[:matcherGroup][:matchers].first[:unaryNumericMatcherData])[:value]
        data_type = (@data[:matcherGroup][:matchers].first[:unaryNumericMatcherData])[:dataType]
        result = {attribute: attribute, value: value, data_type: data_type}
      end
      result
    end

    def matcher_less_than_or_equal
      result = nil
      if self.matcher == 'LESS_THAN_OR_EQUAL_TO'
        attribute = (@data[:matcherGroup][:matchers].first[:keySelector])[:attribute]
        value = (@data[:matcherGroup][:matchers].first[:unaryNumericMatcherData])[:value]
        data_type = (@data[:matcherGroup][:matchers].first[:unaryNumericMatcherData])[:dataType]
        result = {attribute: attribute, value: value, data_type: data_type}
      end
      result
    end

    def matcher_between
      result = nil
      if self.matcher == 'BETWEEN'
        attribute = (@data[:matcherGroup][:matchers].first[:keySelector])[:attribute]
        start_value = (@data[:matcherGroup][:matchers].first[:betweenMatcherData])[:start]
        end_value = (@data[:matcherGroup][:matchers].first[:betweenMatcherData])[:end]
        data_type = (@data[:matcherGroup][:matchers].first[:betweenMatcherData])[:dataType]
        result = {attribute: attribute, start_value: start_value, end_value: end_value, data_type: data_type}
      end
      result
    end

    #
    # @return [object] the negate value for this condition
    def negate
      @data[:matcherGroup][:matchers].first[:negate]
    end

    #
    # @return [object] the array of partitions for this condition
    def partitions
      @partitions
    end

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
    def is_empty?
      @data.empty? ? true : false
    end

  end

end
