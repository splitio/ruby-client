module SplitIoClient
  module Cache
    module Adapters
      module MemoryAdapters
        # Memory adapter implementation, which stores everything inside queue
        class QueueAdapter
          def initialize(size)
            @size = size
            @queue = Queue.new
            @size_counter = Concurrent::AtomicFixnum.new(0)
          end

          # Adds data to queue in non-blocking mode
          def add_to_queue(data)
            fail ThreadError if @size_counter.value >= @size

            @queue.push(data)

            @size_counter.increment
          end

          # Get all items from the queue
          def clear
            items = []

            loop do
              items << @queue.pop(true)

              @size_counter.decrement
            end

          rescue ThreadError
            # Last queue item reached
            items
          end
        end
      end
    end
  end
end
