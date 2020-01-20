# frozen_string_literal: true

class MyImpressionListener
  def initialize
    @queue = Queue.new
  end

  def log(impression)
    @queue.push(impression)
  end

  def size
    @queue.size
  end

  def queue
    items = []
    size.times do
      items << @queue.pop(true)
    end

    items
  end
end
