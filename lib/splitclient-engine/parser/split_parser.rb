module SplitIoClient
  #
  # helper class to parse fetched splits
  #
  class SplitParser < NoMethodError
    #
    # since value for splitChanges last fetch
    attr_accessor :since

    #
    # till value for splitChanges last fetch
    attr_accessor :till

    #
    # splits data
    attr_accessor :splits

    #
    # splits segments data
    attr_accessor :segments

    def initialize(logger)
      @splits = []
      @since = -1
      @till = -1
      @logger = logger
    end

    #
    # gets all the split names retrived from the endpoint
    #
    # @return [object] array of split names
    def get_split_names
      @splits.map { |s| s.name }
    end

    #
    # @return [boolean] true if the splits content is empty false otherwise
    def is_empty?
      @splits.empty? ? true : false
    end

    #
    # gets all the segment names that are used within the retrieved splits
    #
    # @return [object] array of segment names
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

    #
    # gets a split parsed object by name
    #
    # @param name [string] name of the split
    #
    # @return split [object] split object
    def get_split(name)
      @splits.find { |s| s.name == name }
    end

    #
    # gets the treatment for the given combination of user key and split name
    # using all parsed data for the splits
    #
    # @param id [string] user key
    # @param name [string] split name
    # @param default_treatment [string] default treatment value to be returned
    #
    # @return treatment [object] treatment for this user key, split pair
    def get_split_treatment(id, name, default_treatment, attributes = nil)
      split = get_split(name)
      attribute_matchers = ["ATTR_WHITELIST", "EQUAL_TO", "GREATER_THAN_OR_EQUAL_TO", "LESS_THAN_OR_EQUAL_TO", "BETWEEN"]

      if !split.is_empty? && split.status == 'ACTIVE' && !split.killed?
        split.conditions.each do |c|
          unless c.is_empty?
            matcher = get_matcher_type(c)
            matches = attribute_matchers.include?(matcher.matcher_type) ? matcher.match?(attributes) : matcher.match?(id)
            if matches
              result = Splitter.get_treatment(id, split.seed, c.partitions) #'true match - running split'
              if result.nil?
                return default_treatment
              else
                return result
              end
            end
          end
        end
      elsif !split.is_empty? && split.status == 'ARCHIVED'
        return Treatments::CONTROL
      end

      default_treatment
    end

    #
    # gets the matcher type from a condition object
    #
    # @param contidion [object] a condition object
    #
    # @return matcher [object] the matcher object for the given condition
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
        when 'EQUAL_TO'
          final_matcher = EqualToMatcher.new(condition.matcher_equal)
        when 'GREATER_THAN_OR_EQUAL_TO'
          final_matcher = GreaterThanOrEqualToMatcher.new(condition.matcher_greater_than_or_equal)
        when 'LESS_THAN_OR_EQUAL_TO'
          final_matcher = LessThanOrEqualToMatcher.new(condition.matcher_less_than_or_equal)
        when 'BETWEEN'
          final_matcher = BetweenMatcher.new(condition.matcher_between)
        else
          @logger.error('Invalid matcher type')
      end

      final_matcher
    end

  end

end
