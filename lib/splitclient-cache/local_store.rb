require 'thread_safe'

module SplitIoClient
  # A thread-safe in-memory store suitable for use
  # with the Faraday caching HTTP client, uses the
  # Threadsafe gem as the underlying cache.
  #
  class LocalStore
    #
    # Default constructor
    #
    # @return [ThreadSafeMemoryStore] a new store
    def initialize
      @cache = ThreadSafe::Cache.new
    end

    #
    # Read a value from the cache
    # @param key [Object] the cache key
    #
    # @return [Object] the cache value
    def read(key)
      @cache[key]
    end

    #
    # Store a value in the cache
    # @param key [Object] the cache key
    # @param value [Object] the value to associate with the key
    #
    # @return [Object] the value
    def write(key, value)
      @cache[key] = value
    end


    # deletes value from cache by given key
    # @param key [Object] the cache key
    def delete(key)
      @cache[key] = nil
    end

  end

end