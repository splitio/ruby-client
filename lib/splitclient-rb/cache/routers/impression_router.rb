module SplitIoClient
  class ImpressionRouter
    attr_reader :router_thread

    def initialize(config)
      @config = config
      @listener = @config.impression_listener

      return unless @listener

      @queue = Queue.new
      router_thread

      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
          router_thread if forked
        end
      end
    end

    def add_bulk(impressions)
      impressions.each do |impression|
        enqueue(
          split_name: impression[:i][:f],
          matching_key: impression[:i][:k],
          bucketing_key: impression[:i][:b],
          time: impression[:i][:m],
          treatment: {
            label: impression[:i][:r],
            treatment: impression[:i][:t],
            change_number: impression[:i][:c]
          },
          previous_time: impression[:i][:pt],
          attributes: impression[:attributes]
        ) unless impression.nil?
      end
    rescue StandardError => error
      @config.log_found_exception(__method__.to_s, error)
    end

    private

    def enqueue(impression)
      @queue.push(impression) if @listener
    rescue StandardError => error
      @config.log_found_exception(__method__.to_s, error)
    end

    def router_thread
      @config.threads[:impression_router] = Thread.new do
        loop do
          begin
            @config.logger.warn("THREAD POP loop")
            impression = @queue.pop
            @config.logger.warn(impression.to_s)
            @listener.log(impression)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end

        @config.logger.warn("final router loop thread..")
      end
    end
  end
end
