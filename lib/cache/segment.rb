class SplitIoClient::Cache::Segment
  def initialize(adapter)
    @adapter = adapter.new
  end

  def []=(name, keys)
    @adapter.set(name, keys)
  end

  def [](name)
    @adapter.get(name)
  end

  def add_keys(name, keys)
    self[name] = (self[name].empty? ? keys : [self[name], keys].flatten)
  end

  def remove_keys(name, keys)
    new_keys = @adapter.get(name).reject { |key| keys.include? key }

    self[name] = new_keys
  end

  def in?(name, key)
    self[name].include? key
  end
end
