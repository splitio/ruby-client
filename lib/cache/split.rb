class SplitIoClient::Cache::Split
  def initialize(adapter)
    @adapter = adapter

    @adapter['since'] = -1
    @adapter['splits'] = []
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

  def add(split)
    stored_splits = self['splits']
    refreshed_splits = stored_splits.reject { |s| s[:name] == split[:name] }

    self['splits'] = refreshed_splits + [split]
  end

  def find(name)
    self['splits'].find { |s| s[:name] == name }
  end

  def used_segments_names
    self['splits'].each_with_object([]) do |split, names|
      SplitIoClient::Split.new(split).conditions.each do |condition|
        next if condition.matchers.nil?

        condition.matchers.each do |matcher|
          next if matcher[:userDefinedSegmentMatcherData].nil?

          names << matcher[:userDefinedSegmentMatcherData].values
        end
      end
    end.flatten.uniq
  end
end
