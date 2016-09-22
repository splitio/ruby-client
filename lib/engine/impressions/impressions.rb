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
      @queue = Queue.new
      @max_number_of_keys = max
    end

    #
    # generates a new entry for impressions list
    #
    # @param id [string] user key
    # @param feature [string] feature name
    # @param treatment [string] treatment value
    # @param label [string] label value
    # @param time [time] time value in milisenconds
    #
    # @return void
    def log(id, feature, treatment, label, time)
      impressions = KeyImpressions.new(id, treatment, label, time)
      @queue << {feature: feature, impressions: impressions}
    end

    #
    # clears the impressions queue
    #
    # @returns void
    def clear
      popped_impressions = []
      begin
        loop do
          impression_element = @queue.pop(true)
          feature_hash = popped_impressions.find { |i| i[:feature] == impression_element[:feature] }
          if feature_hash.nil?
            popped_impressions << {feature: impression_element[:feature], impressions: [] << impression_element[:impressions]}
          else
            feature_hash[:impressions] << impression_element[:impressions]
          end
        end
      rescue ThreadError
      end
      popped_impressions
    end

  end

  #
  # small class to use as DTO for impressions
  #
  class KeyImpressions
    attr_accessor :key
    attr_accessor :treatment
    attr_accessor :label
    attr_accessor :time

    def initialize(key, treatment, label, time)
      @key = key
      @treatment = treatment
      @treatment = label
      @time = time
    end
  end

end
