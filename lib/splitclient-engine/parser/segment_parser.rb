module SplitIoClient

  class SegmentParser < NoMethodError
    attr_accessor :segments
    attr_accessor :since

    def initialize(logger)
      @segments = []
      @since = -1
      @logger = logger
    end

    def get_segment(name)
      @segments.find { |s| s.name == name }
    end

    def get_segment_names
      @segments.map { |seg| seg.name }
    end

    def is_empty?
      @segments.empty? ? true : false
    end

  end

end