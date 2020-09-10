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
      return unless @listener
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
    end

    private

    def enqueue(impression)
      @queue.push(impression) if @listener
    end

    def router_thread
      @config.threads[:impression_router] = Thread.new do
        loop do
          begin
            @listener.log(@queue.pop)
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end
  end
end
