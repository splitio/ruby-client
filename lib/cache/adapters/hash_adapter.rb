class SplitIoClient::Cache::Adapters::HashAdapter
  def initialize
    @hash = {}
  end

  def add(key, obj)
    @hash[key] = obj
  end

  def remove(key)
    @hash.delete(key)
  end
end
