module SplitIoClient

  class Impressions < NoMethodError

    attr_accessor :queue
    attr_accessor :max_number_of_keys

    def initialize(max)
      @queue = []
      @max_number_of_keys = max
    end

    def log(id, feature, treatment, time)
      impressions_hash = @queue.find { |i| i[:feature] == feature }
      if impressions_hash.nil?
        impressions = [KeyImpressions.new(id, treatment, time)]
        @queue << {feature: feature, impressions: impressions}
      else
        impressions = impressions_hash[:impressions]
        if impressions.size >= @max_number_of_keys
          impressions << KeyImpressions.new(id, treatment, time)
          impressions_hash[:impressions].replace(impressions)
        else
          impressions << KeyImpressions.new(id, treatment, time)
          impressions_hash[:impressions].replace(impressions)
        end
      end
    end

    def clear
      @queue = []
    end

  end

  class KeyImpressions
    attr_accessor :key
    attr_accessor :treatment
    attr_accessor :time

    def initialize(key, treatment, time)
      @key = key
      @treatment = treatment
      @time = time
    end
  end

end
