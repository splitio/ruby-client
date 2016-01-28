module SplitIoClient

  class Split < NoMethodError
    attr_accessor :data

    def initialize(split)
      @data = split
      @conditions = set_conditions
    end

    def name
      @data[:name]
    end

    def seed
      @data[:seed]
    end

    def status
      @data[:status]
    end

    def killed?
      @data[:killed]
    end

    def conditions
      @conditions
    end

    def is_empty?
      @data.empty? ? true : false
    end

    def set_conditions
      conditions_list = []
      @data[:conditions].each do |c|
        condition = SplitIoClient::Condition.new(c)
        conditions_list << condition
      end
      conditions_list
    end

  end

end