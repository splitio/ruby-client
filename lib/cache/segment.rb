class SplitIoClient::Cache::Segment
  def initialize(adapter)
    @adapter = adapter

    @adapter['since'] = -1
    @adapter['segments'] = []
    @adapter['added_users'] = []
    @adapter['removed_users'] = []
  end

  def []=(key, obj)
    @adapter[key] = obj
  end

  def [](key)
    @adapter[key]
  end

  def add(segment)
    stored_segments = self['segments']

    self['segments'] = stored_segments + [segment]
  end

  def find(name)
    self['segments'].find { |s| s[:name] == name }
  end
end
