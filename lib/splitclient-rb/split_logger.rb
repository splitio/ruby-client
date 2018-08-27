require 'singleton'

module SplitIoClient
  class SplitLogger
      attr_accessor :config
      include Singleton

      def self.split_config(config)
        instance.config = config
      end

      def log_if_debug(message)
        config.logger.debug(message) if config.debug_enabled
      end

      def log_if_transport(message)
        config.logger.debug(message) if config.transport_debug_enabled
      end

      def log_error(message)
        config.logger.error(message)
      end

      class << self
        extend Forwardable
        def_delegators :instance, *SplitLogger.instance_methods(false)
      end
  end
end
