module SplitIoClient

  class SegmentParser < NoMethodError
    attr_accessor :segments
    attr_accessor :since

    def initialize
      @segments = {}
      @since = -1
    end

    def get_segment_names
      segment_names = @segments.map{|seg| seg[:name]}
    end

    def is_empty?
      @segments.empty? ? true : false
    end
  end

end