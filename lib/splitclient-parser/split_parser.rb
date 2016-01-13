module SplitIoClient

  class SplitParser < NoMethodError
    attr_accessor :since
    attr_accessor :till
    attr_accessor :splits

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
  end

end