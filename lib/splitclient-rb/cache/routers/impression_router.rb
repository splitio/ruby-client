module SplitIoClient
  class ImpressionRouter
    attr_reader :router_thread

    def initialize(config)
      @config = config
      @listener = config.impression_listener
      @queue = Queue.new
      router_thread

      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
          router_thread if forked
        end
      end
    end

    def add(impression)
      @queue.push(impression)
    end

    def add_bulk(impressions)
      impressions[:split_names].each do |split_name|
        @queue.push(
          split_name: split_name.to_s,
          matching_key: impressions[:matching_key],
          bucketing_key: impressions[:bucketing_key],
          treatment: {
            label: impressions[:treatments_labels_change_numbers][split_name.to_sym][:label],
            treatment: impressions[:treatments_labels_change_numbers][split_name.to_sym][:treatment],
            change_number: impressions[:treatments_labels_change_numbers][split_name.to_sym][:change_number]
          },
          attributes: impressions[:attributes]
        )
      end
    end

    private

    def router_thread
      @config.threads[:impression_router] = Thread.new do
        loop do
          begin
            impression = @queue.pop
            @listener.log(impression) if @listener
          rescue StandardError => error
            @config.log_found_exception(__method__.to_s, error)
          end
        end
      end
    end
  end
end
