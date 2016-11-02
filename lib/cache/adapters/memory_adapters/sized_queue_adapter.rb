module SplitIoClient
  module Cache
    module Adapters
      module MemoryAdapters
        class SizedQueueAdapter
          def initialize(size)
            @size = size
            @queue = SizedQueue.new(queue_size)
          end

          def add_to_queue(data)
            @queue.push(data, true)
          end

          def clear
            items = []

            loop { items << @queue.pop(true) }
          rescue ThreadError
            # last queue item reached
            items
          end

          private

          def queue_size
            @size <= 0 ? 1 : @size
          end
        end
      end
    end
  end
end
