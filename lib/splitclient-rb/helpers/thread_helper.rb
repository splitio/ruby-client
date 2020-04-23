# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class ThreadHelper
      def self.stop(thread_sym, config)
        thread = config.threads[thread_sym]

        unless thread.nil?
          config.logger.debug("Stopping #{thread_sym} ...") if config.debug_enabled
          sleep(0.1) while thread.status == 'run'
          Thread.kill(thread)
        end
      rescue StandardError => e
        config.logger.error(e.inspect)
      end

      def self.alive?(thread_sym, config)
        thread = config.threads[thread_sym]

        thread.nil? ? false : thread.status.alive?
      end
    end
  end
end
