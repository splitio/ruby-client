module SplitIoClient
  module Cache
    module Adapters
      module MemoryAdapters
        # Memory adapter implementation, which stores everything inside queue
        class QueueAdapter
          def initialize(max_size)
            @max_size = max_size
            @queue = Queue.new
            @current_size = Concurrent::AtomicFixnum.new(0)
          end

          def clear(_ = nil)
            @queue = Queue.new
            @current_size.value = 0
          end

          # Adds data to queue in non-blocking mode
          def add_to_queue(data)
            fail ThreadError if @current_size.value >= @max_size

            @queue.push(data)

            @current_size.increment
          end

          def clear
            get_batch(@current_size.value)
          end

          def get_batch(size)
            items = []
            size.times do
              items << @queue.pop(true)
              @current_size.decrement
            end
            items
            rescue ThreadError
            items
          end

        end
      end
    end
  end
end
