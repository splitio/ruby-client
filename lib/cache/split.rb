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

  def add_split(split)
    @adapter['splits'] = [] if @adapter['splits'].nil?

    @adapter['splits'] << split
  end

  def refresh_splits(split)
    @adapter['splits'].delete_if { |s| s[:name] == split[:name] }

    add_split(split)
  end

  def add_and_refresh(split)
    add_split(split)
    refresh_splits(split)
  end

  def since
    @since || -1
  end
end
