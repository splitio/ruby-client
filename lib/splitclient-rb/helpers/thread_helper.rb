# frozen_string_literal: true

module SplitIoClient
  module Helpers
    class ThreadHelper
      def self.stop(thread_sym, config)
        thread = config.threads[thread_sym]

        sleep(0.1) while thread.status == 'run'

        Thread.kill(thread)
      rescue StandardError => error
        config.logger.error(error.inspect)
      end
    end
  end
end
