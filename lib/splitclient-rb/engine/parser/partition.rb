module SplitIoClient
  #
  # acts as dto for a partition structure
  #
  class Partition < NoMethodError

    #
    # definition of the condition
    #
    # @returns [object] condition values
    attr_accessor :data

    def initialize(partition)
      @data = partition
    end

    #
    # @return [object] the treatment value for this partition
    def treatment
      @data[:treatment]
    end

    #
    # @return [object] the size value for this partition
    def size
      @data[:size]
    end

    #
    # @return [boolean] true if the partition is empty false otherwise
    def is_empty?
      @data.empty?
    end
  end
end
