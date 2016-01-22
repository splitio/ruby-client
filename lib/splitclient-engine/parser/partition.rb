module SplitIoClient

  class Partition < NoMethodError
    attr_accessor :data

    def initialize(partition)
      @data = partition
    end

    def treatment
      @data[:treatment]
    end

    def size
      @data[:size]
    end

    def is_empty?
      @data.empty? ? true : false
    end
  end

end