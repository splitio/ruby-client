module SplitIoClient

  class Impressions < NoMethodError

    attr_reader :queue
    attr_reader :max_number_of_keys

    def initialize(max)
      @queue = {}
      @max_number_of_keys =  max
    end

    def log(id, feature, treatment, time)
      impressions =  @queue.find{|i| i[:feature] == feature}
      if impressions.nil?
        impressions << KeyImpressions.new(id, treatment, time)
        @queue.merge!({feature:feature, impressions: impressions})
      elsif impressions.size >= @max_number_of_keys
        impressions << KeyImpressions.new(id, treatment, time)
        @queue.merge!({feature:feature, impressions: impressions})
      else
        impressions << KeyImpressions.new(id, treatment, time)
      end
      return
    end
  end

  class KeyImpressions
    attr_accessor :key
    attr_accessor :treatment
    attr_accessor :time

    def initialize(key, treatment, time)
      @key =  key
      @treatment = treatment
      @time = time
    end
  end

end
