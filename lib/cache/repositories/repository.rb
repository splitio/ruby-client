module SplitIoClient
  module Cache
    class Repository
      def initialize(adapter)
        @adapter = adapter

        @adapter[namespace_key('ready')] = false
      end

      def []=(key, obj)
        @adapter[namespace_key(key)] = obj
      end

      def [](key)
        @adapter[namespace_key(key)]
      end

      protected

      def namespace_key(key)
        "repository_#{key}"
      end
    end
  end
end
