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
    # @return [object] the whitelist for this condition in case it has a whitelist matcher
    def matcher_whitelist
      result = nil
      if self.matcher == 'WHITELIST'
        result = (@data[:matcherGroup][:matchers].first[:whitelistMatcherData])[:whitelist]
      end
      result
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