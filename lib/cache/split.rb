class SplitIoClient::Cache::Split
  def initialize(adapter)
    @adapter = adapter
  end

  def []=(name, keys)
    @adapter.set(name, keys)
  end

  def [](name)
    @adapter.get(name)
  end

  def remove(name)
    @adapter.remove(name)
  end

  def <<(data)
    @adapter['splits'] = [] if @adapter[name].nil?

    @adapter['splits'] = [@adapter['splits'], data].flatten
  end
end
