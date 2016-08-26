require "countdownlatch"

module SplitIoClient
  class SDKReadinessGate < NoMethodError

    def initialize(logger)
      @splits_are_ready = CountDownLatch.new 1
      @segments_are_ready = {}
      @logger = logger
      @gate_is_open = false
    end

    def is_sdk_ready?()
      @gate_is_open
    end

    def is_open?
      @gate_is_open == true
    end

    def is_gate_ready?(seconds)
      if seconds == 0 && are_segments_ready?(seconds)
        @gate_is_open = true
      elsif seconds == 0 && !are_segments_ready?(seconds)
        @gate_is_open = false
      else
        @gate_is_open = seconds
      end
    end

    def are_segments_ready?(seconds)
      return false if @segments_are_ready.empty?
      @segments_are_ready.each do |segment|
        segment_name = segment[0]
        return unless segment_is_ready?(segment_name)
      end
      return true
    end

    def segment_is_ready?(segment_name)
      count_down_latch = @segments_are_ready[segment_name]
      return unless count_down_latch
      original_count = count_down_latch.count
      count_down_latch.countdown!
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
        @splits_are_ready.wait(seconds) unless seconds == 0
        true
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
