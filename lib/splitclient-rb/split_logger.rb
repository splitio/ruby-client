module SplitIoClient
  class SplitLogger
      def initialize(config)
        @config = config
      end

      def log_if_debug(message)
        @config.logger.debug(message) if enabled_log?(@config.debug_enabled, message)
      end

      def log_if_transport(message)
        @config.logger.debug(message) if enabled_log?(@config.transport_debug_enabled, message)
      end

      private
      def enabled_log?(debug_enabled, message)
        message = message.to_s

        debug_enabled && !message.empty? && message != '{}'
      end
  end
end
