module SplitIoClient

  class Condition < NoMethodError
    attr_accessor :data

    def initialize(condition)
      @data = condition
      @partitions = set_partitions
    end

    def combiner
      @data[:matcherGroup][:combiner]
    end

    def matcher
      @data[:matcherGroup][:matchers].first[:matcherType]
    end

    def matchers
      @data[:matcherGroup][:matchers]
    end

    def matcher_whitelist
      result = nil
      if self.matcher == 'WHITELIST'
        result = (@data[:matcherGroup][:matchers].first[:whitelistMatcherData])[:whitelist]
      end
      result
    end

    def matcher_segment
      result = nil
      if self.matcher == 'IN_SEGMENT'
        result = (@data[:matcherGroup][:matchers].first[:userDefinedSegmentMatcherData])[:segmentName]
      end
      result
    end


    def negate
      @data[:matcherGroup][:matchers].first[:neagte]
    end

    def partitions
      @partitions
    end

    def set_partitions
      partitions_list = []
      @data[:partitions].each do |p|
        partition = SplitIoClient::Partition.new(p)
        partitions_list << partition
      end
      return partitions_list
    end

    def is_empty?
      @data.empty? ? true : false
    end
  end

end