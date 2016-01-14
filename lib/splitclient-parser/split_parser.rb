module SplitIoClient

  class SplitParser < NoMethodError
    attr_accessor :since
    attr_accessor :till
    attr_accessor :splits
    attr_accessor :segments

    def initialize
      @splits = {}
      @since = -1
      @till = -1
    end

    def get_split_names
      feature_names = @splits.map{|s| s[:name]}
    end

    def is_empty?
      @splits.empty? ? true : false
    end

    def get_used_segments
      segment_names = []

      @splits.each { |s|
        s[:conditions].each { |c|
          matchers_section = c[:matcherGroup][:matchers]
          matchers_section.each { |m|
            m[:userDefinedSegmentMatcherData].each{ |seg, name|
              segment_names << name
            } unless m[:userDefinedSegmentMatcherData].nil?
          } unless matchers_section.nil?
        }
      }

      return segment_names.uniq
    end

    def get_split(name)
      @splits.find{|s| s[:name] == name}
    end

    def get_split_treatment(id, name)
      split = get_split(name)
      conditions = split[:conditions]
      matcher = nil

      conditions.each do |c|
        matchers_section = c[:matcherGroup][:matchers]
        matchers_section.each { |m|
          puts '=========='
          matcher = get_matcher_type(m)
          puts matcher.to_s
          if matcher.match?(id)

          end
          puts '=========='
        } unless matchers_section.nil?
      end
    end

    def get_matcher_type(matcher)
      final_matcher = nil

      case matcher[:matcherType]
        when 'ALL_KEYS'
          final_matcher = AllKeysMatcher.new
        when 'IN_SEGMENT'
          segment = @segments.get_segment((matcher[:userDefinedSegmentMatcherData])[:segmentName])
          final_matcher = UserDefinedSegmentMatcher.new(segment)
        when 'WHITELIST'
          whitelist = (matcher[:whitelistMatcherData])[:whitelist]
          final_matcher = WhitelistMatcher.new(whitelist)
        else
          #TODO log error invalid matcher type
      end

      return final_matcher

    end

  end

end