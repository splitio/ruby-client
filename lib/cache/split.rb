class SplitIoClient::Cache::Split
  def initialize(adapter)
    @adapter = adapter.new
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
end
