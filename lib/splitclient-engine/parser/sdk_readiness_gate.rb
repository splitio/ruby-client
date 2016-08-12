require "countdownlatch"

module SplitIoClient
  class SDKReadinessGate < NoMethodError

    def initialize(logger)
      @splits_are_ready = CountDownLatch.new 1
      @segments_are_ready = {}
      @logger = logger
    end

    def is_sdk_ready?(seconds)
      are_splits_ready?(seconds) ? are_segments_ready?(seconds) : false
    end

    def are_segments_ready?(seconds)
      end_time = seconds + 5
      time_left = seconds
      @segments_are_ready.each do |segment|
        segment_name = segment[0]
        count_down_latch = segment[1]

        unless count_down_latch.wait(time_left)
          @logger.error "#{segment_name} is not ready yet"
          return false
        end
      end

      return true
    end

    def segment_is_ready?(segment_name)
      count_down_latch = @segments_are_ready[segment_name]
      return unless count_down_latch
      original_count = count_down_latch.count
      count_down_latch.count_down!
      @logger.debug "#{segment_name} is ready!" if original_count > 0
    end

    def register_segments(segment_names)
      return false if segment_names.empty?
      segment_names.uniq.each { |segment_name| @segments_are_ready[segment_name] = CountDownLatch.new(1) }
      @logger.debug "Registered segments: #{@segments_are_ready.keys.join(",")}"
    end

    def splits_are_ready
      original_count = @splits_are_ready.count
      @splits_are_ready.countdown!
      @logger.debug "splits are ready" if original_count == 0
    end

    def are_splits_ready?(seconds)
      begin
        p "===== #{seconds}"
        @splits_are_ready.wait(seconds)
      rescue
        raise InterrumpedException.new(nil)
      end
    end

    class InterrumpedException < StandardError
      def initialize(message)
        super(message)
      end
    end
  end
end
