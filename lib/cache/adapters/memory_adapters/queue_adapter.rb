module SplitIoClient
  module Cache
    module Adapters
      module MemoryAdapters
        # Memory adapter implementation, which stores everything inside queue
        class QueueAdapter
          def initialize(size)
            @size = size
            @queue = Queue.new
          end

          # Adds data to queue in non-blocking mode
          def add_to_queue(data)
            @queue.push(data)
          end

          # Get all items from the queue
          def clear
            items = []

            loop { items << @queue.pop(true) }

          rescue ThreadError
            # Last queue item reached
            items
          end
        end
      end
    end
  end
end
