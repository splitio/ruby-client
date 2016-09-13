module SplitIoClient
  #
  # helper class to parse fetched segments
  #
  class SegmentParser < NoMethodError
    #
    # segments data
    attr_accessor :segments

    #
    # since value for segments
    attr_accessor :since

    def initialize(logger)
      @segments = []
      @since = -1
      @logger = logger
    end

    #
    # method to get a segment by name
    #
    # @param name [string] segment name
    #
    # @return [object] segment object
    def get_segment(name)
      @segments.find { |s| s.name == name }
    end

    #
    # method to get all segment names within the structure
    #
    # @return [object] array of segment names
    def get_segment_names
      @segments.map { |seg| seg.name }
    end

    #
    # @return [boolean] true if the segment parser data is empty false otherwise
    def empty?
      @segments.empty?
    end

    def to_h
      {
        segments: segments,
        since: since
      }
    end
  end
end
