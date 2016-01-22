module SplitIoClient

  class Segment < NoMethodError
    attr_accessor :data

    def initialize(segment)
      @data = segment
    end

    def name
      @data[:name]
    end

    def since
      @data[:since]
    end

    def till
      @data[:till]
    end

    def added
      @data[:added]
    end

    def removed
      @data[:removed]
    end

    def is_empty?
      @data.empty? ? true : false
    end
  end

end