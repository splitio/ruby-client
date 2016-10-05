module SplitIoClient
  #
  # acts as dto for a split structure
  #
  class Split < NoMethodError
    #
    # definition of the split
    #
    # @returns [object] split values
    attr_accessor :data

    def initialize(split)
      @data = split
      @conditions = set_conditions
    end

    #
    # @returns [string] name of the split
    def name
      @data[:name]
    end

    #
    # @returns [int] seed value of the split
    def seed
      @data[:seed]
    end

    #
    # @returns [string] status value of the split
    def status
      @data[:status]
    end

    #
    # @returns [string] killed value of the split
    def killed?
      @data[:killed]
    end

    #
    # @returns [object] array of condition objects for this split
    def conditions
      @conditions
    end

    #
    # @return [boolean] true if the condition is empty false otherwise
    def empty?
      @data.empty?
    end

    #
    # converts the conditions data into an array of condition objects for this split
    #
    # @return [object] array of condition objects
    def set_conditions
      conditions_list = []
      @data[:conditions].each do |c|
        condition = SplitIoClient::Condition.new(c)
        conditions_list << condition
      end
      conditions_list
    end

    def to_h
      {
        name: name,
        seed: seed,
        status: status,
        killed: killed?,
        conditions: conditions
      }
    end
  end
end
