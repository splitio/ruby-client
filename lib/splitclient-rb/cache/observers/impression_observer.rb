module SplitIoClient
  module Observers
    class ImpressionObserver
      LAST_SEEN_CACHE_SIZE = 500000

      def initialize
        @cache = LruRedux::TTL::ThreadSafeCache.new(LAST_SEEN_CACHE_SIZE, true)
        @impression_hasher = Hashers::ImpressionHasher.new
      end

      def test_and_set(impression)
        return if impression.nil?

        hash = @impression_hasher.process(impression)
        previous = @cache[hash]
        @cache[hash] = impression[:m]

        previous.nil? ? nil : [previous, impression[:m]].min
      end
    end
  end
end
