# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class ThreadHelper
      def self.stop(thread_sym, config)
        thread = config.threads[thread_sym]

        # Never kill the calling thread: stop_sse is reachable from inside the token
        # refresh thread, which would otherwise terminate itself mid-flight.
        return if thread == Thread.current

        unless thread.nil?
          config.logger.debug("Stopping #{thread_sym} thread...") if config.debug_enabled
          Thread.kill(thread)
        end
      rescue StandardError => e
        config.logger.error(e.inspect)
      end

      # Terminates the thread currently held in +thread_sym+ before its handle is
      # replaced. Thread handles live in a single slot per symbol, so overwriting one
      # while the thread is still running makes it unreachable and leaks it forever.
      def self.reap(thread_sym, config, timeout = 1)
        thread = config.threads[thread_sym]
        return if thread.nil? || thread == Thread.current || !thread.alive?

        config.logger.warn("#{thread_sym} thread is still alive, terminating it before starting a new one.")
        Thread.kill(thread) unless thread.join(timeout)
      rescue StandardError => e
        config.logger.error(e.inspect)
      end

      def self.alive?(thread_sym, config)
        thread = config.threads[thread_sym]

        thread.nil? ? false : thread.alive?
      end
    end
  end
end
