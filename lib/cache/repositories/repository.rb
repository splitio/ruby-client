module SplitIoClient
  module Cache
    class Repository
      def initialize(adapter)
        @adapter = adapter

        @adapter.set_bool(namespace_key('ready'), false)
      end

      def set_string(key, str)
        @adapter.set_string(namespace_key(key), str)
      end

      def string(key)
        @adapter.string(namespace_key(key))
      end

      protected

      def namespace_key(key)
        "repository_#{key}"
      end
    end
  end
end
