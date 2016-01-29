module SplitIoClient

  #
  # class to manage cached impressions
  #
  class Impressions < NoMethodError

    # the queue of cached impression values
    #
    # @return [object] array of impressions
    attr_accessor :queue

    # max number of cached entries for impressions
    #
    # @return [int] max numbre of entries
    attr_accessor :max_number_of_keys

    #
    # initializes the class
    #
    # @param max [int] max number of cached entries
    def initialize(max)
      @queue = []
      @max_number_of_keys = max
    end

    #
    # generates a new entry for impressions list
    #
    # @param id [string] user key
    # @param feature [string] feature name
    # @param treatment [string] treatment value
    # @param time [time] time value in milisenconds
    #
    # @return void
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

    #
    # clears the impressions queue
    #
    # @returns void
    def clear
      @queue = []
    end

  end

  #
  # small class to use as DTO for impressions
  #
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
