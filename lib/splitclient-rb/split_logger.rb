module SplitIoClient
  class SplitLogger
      def initialize(config)
        @config = config
      end

      def log_if_debug(message)
        @config.logger.debug(message) if @config.debug_enabled
      end

      def log_if_transport(message)
        @config.logger.debug(message) if @config.transport_debug_enabled
      end
  end
end
