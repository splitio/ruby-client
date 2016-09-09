module SplitIoClient
  module Cache
    module Adapters
      class HashAdapter < Adapter
        def initialize
          @hash = {}
        end

        def set(key, obj)
          @hash[key] = obj
        end

        def get(key)
          @hash[key]
        end

        def remove(key)
          @hash.delete(key)
        end

        def key?(key)
          @hash.key?
        end
      end
    end
  end
end
