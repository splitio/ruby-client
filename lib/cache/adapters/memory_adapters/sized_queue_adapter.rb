module SplitIoClient
  module Cache
    module Adapters
      module MemoryAdapters
        # Memory adapter implementation, which stores everything inside sized queue
        class SizedQueueAdapter
          def initialize(size)
            @size = size
            @queue = SizedQueue.new(queue_size)
          end

          # Adds data to queue in non-blocking mode
          def add_to_queue(data)
            @queue.push(data, true)
          end

          # Get all items from the queue
          def clear
            items = []

            loop { items << @queue.pop(true) }
          rescue ThreadError
            # Last queue item reached
            items
          end

          private

          # Return 1 to prevent an exception
          def queue_size
            @size <= 0 ? 1 : @size
          end
        end
      end
    end
  end
end
