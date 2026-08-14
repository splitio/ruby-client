# frozen_string_literal: true

module SplitIoClient
  module Engine
    # Governs how aggressively streaming reconnects are attempted.
    #
    # Extracted for FME-18143, where a customer's SDK reconnected up to ~64 times per
    # second and accumulated ~10,000 threads. Two properties matter here:
    #
    #   * A connection only earns a back off reset if it stayed up long enough to count
    #     as a genuine success. Resetting on every PUSH_CONNECTED meant a connection
    #     that lived for milliseconds still produced a zero second retry.
    #   * Only one reconnect may be in flight at a time, and errors describing an
    #     already-replaced connection must not each start another one.
    class ReconnectPolicy
      # How long a connection must survive before it counts as stable.
      MIN_UPTIME_FOR_BACKOFF_RESET = 30

      def initialize(config, status_queue, back_off = nil)
        @config = config
        @status_queue = status_queue
        @back_off = back_off || Engine::BackOff.new(1, 3)
        @connected_at = Concurrent::AtomicReference.new(nil)
        @reconnecting = Concurrent::AtomicBoolean.new(false)
      end

      def connected
        @connected_at.set(Time.now)
      end

      # Whether a disconnect should be acted on at all. Returns false for a disconnect
      # of an already-disconnected stream, and for a reconnect when one is already in
      # flight (typically driven by the token refresh thread) -- running two
      # concurrently is what multiplied connection attempts.
      def actionable?(sse_connected, reconnect)
        unless sse_connected || reconnect
          log_debug('Streaming already disconnected.')
          return false
        end
        return true unless reconnect && !acquire

        log_debug('Streaming reconnect already in progress, ignoring.')
        false
      end

      # Returns true only for the caller that acquired the right to reconnect; a
      # concurrent caller gets false. AtomicBoolean#make_true is the compare-and-set:
      # it returns true only for the transition from false to true.
      def acquire
        @reconnecting.make_true
      end

      def release
        @reconnecting.make_false
      end

      # Resets the back off only if the connection that just dropped was stable, so a
      # flapping connection keeps backing off instead of retrying immediately.
      def record_disconnect
        connected_at = @connected_at.get_and_set(nil)
        return if connected_at.nil?

        uptime = Time.now - connected_at
        return if uptime < MIN_UPTIME_FOR_BACKOFF_RESET

        log_debug("Streaming connection was up for #{uptime.round(1)}s, resetting back off.")
        @back_off.reset
      end

      def interval
        @back_off.interval
      end

      # Drops queued retryable errors, which refer to the connection just replaced.
      # Acting on each of them would start one more reconnect apiece. Other statuses
      # are preserved in order.
      def discard_stale_errors
        kept = []
        discarded = 0

        until @status_queue.empty?
          status = @status_queue.pop(true)
          if status == Constants::PUSH_RETRYABLE_ERROR
            discarded += 1
          else
            kept << status
          end
        end

        kept.each { |kept_status| @status_queue.push(kept_status) }
        log_debug("Discarded #{discarded} stale streaming errors.") if discarded.positive?
        discarded
      rescue ThreadError
        discarded
      end

      private

      def log_debug(message)
        @config.logger.debug(message) if @config.debug_enabled
      end
    end
  end
end
