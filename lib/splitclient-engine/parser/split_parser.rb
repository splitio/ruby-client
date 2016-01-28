module SplitIoClient

  class SplitParser < NoMethodError
    attr_accessor :since
    attr_accessor :till
    attr_accessor :splits
    attr_accessor :segments

    def initialize(logger)
      @splits = []
      @since = -1
      @till = -1
      @logger = logger
    end

    def get_split_names
      @splits.map { |s| s.name }
    end

    def is_empty?
      @splits.empty? ? true : false
    end

    def get_used_segments
      segment_names = []

      @splits.each { |s|
        s.conditions.each { |c|
          c.matchers.each { |m|
            m[:userDefinedSegmentMatcherData].each { |seg, name|
              segment_names << name
            } unless m[:userDefinedSegmentMatcherData].nil?
          } unless c.matchers.nil?
        }
      }

      segment_names.uniq
    end

    def get_split(name)
      @splits.find { |s| s.name == name }
    end

    def get_split_treatment(id, name)
      split = get_split(name)
      default = Treatments::CONTROL

      if !split.is_empty? && split.status == 'ACTIVE' && !split.killed?
        split.conditions.each do |c|
          unless c.is_empty?
            matcher = get_matcher_type(c)
            if matcher.match?(id)
              return Splitter.get_treatment(id, split.seed, c.partitions) #'true match - running split'
            end
          end
        end
      end

      default
    end

    def get_matcher_type(condition)
      final_matcher = nil

      case condition.matcher
        when 'ALL_KEYS'
          final_matcher = AllKeysMatcher.new
        when 'IN_SEGMENT'
          segment = @segments.get_segment(condition.matcher_segment)
          final_matcher = segment.is_empty? ? UserDefinedSegmentMatcher.new(nil) : UserDefinedSegmentMatcher.new(segment)
        when 'WHITELIST'
          final_matcher = WhitelistMatcher.new(condition.matcher_whitelist)
        else
          @logger.error('Invalid matcher type')
      end

      final_matcher
    end

  end

end