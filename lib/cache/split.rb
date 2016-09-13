class SplitIoClient::Cache::Split
  attr_writer :since

  def initialize(adapter)
    @adapter = adapter
  end

  def []=(key, obj)
    @adapter[key] = obj
  end

  def [](key)
    @adapter[key]
  end

  def remove(key)
    @adapter.remove(key)
  end

  def add_splits(data)
    @adapter['splits'] = [] if @adapter['splits'].nil?

    @adapter['splits'] = [@adapter['splits'], data].flatten
  end

  def refresh_splits(data)
    names = [data].flatten.map { |s| s[:name] }
    refreshed_splits = @adapter['splits'].delete_if { |s| names.include? s[:name] }

    @adapter['splits'] = [refreshed_splits, data].flatten
  end

  def add_and_refresh(data)
    add_splits(data)
    refresh_splits(data)
  end

  def since
    @since || -1
  end
end
