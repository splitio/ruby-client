module SplitIoClient
  module Cache
    module Adapters
      class Adapter
        def set
          raise NoMethodError
        end

        def get
          raise NoMethodError
        end

        def remove
          raise NoMethodError
        end

        def key?
          raise NoMethodError
        end
      end
    end
  end
end
