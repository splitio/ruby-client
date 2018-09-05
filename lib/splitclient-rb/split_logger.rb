require 'singleton'

module SplitIoClient
  class SplitLogger
      include Singleton

      def log_if_debug(message)
        SplitIoClient.configuration.logger.debug(message) if SplitIoClient.configuration.debug_enabled
      end

      def log_if_transport(message)
        SplitIoClient.configuration.logger.debug(message) if SplitIoClient.configuration.transport_debug_enabled
      end

      def log_error(message)
        SplitIoClient.configuration.logger.error(message)
      end

      class << self
        extend Forwardable
        def_delegators :instance, *SplitLogger.instance_methods(false)
      end
  end
end
