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
    # @param config [SplitConfig] the config object
    def initialize(config)
      @config = config
      @queue = SizedQueue.new(config.impressions_queue_size <= 0? 1 : config.impressions_queue_size)
      @max_number_of_keys = config.impressions_queue_size
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
      return if @max_number_of_keys <= 0 # shortcut to desable impressions
      impressions = KeyImpressions.new(id, treatment, time)
      begin 
        @queue.push( {feature: feature, impressions: impressions} , true ) # don't wait if queue is full
      rescue ThreadError
        if Random.new.rand(1..1000) <= 2 # log only 0.2 % of the time.
          @config.logger.warn("Dropping impressions. Current size is #{@max_number_of_keys}. Consider increasing impressions_queue_size")
        end
      end
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
    attr_accessor :time

    def initialize(key, treatment, time)
      @key = key
      @treatment = treatment
      @time = time
    end
  end

end
