module SplitIoClient
  class EqualToSetMatcher < SetMatcher
    def self.matcher_type
      'EQUAL_TO_SET'.freeze
    end

    def initialize(attribute, remote_array)
      super(attribute, remote_array)
    end

    def match?(_key, data)
      local_set(data, @attribute) == @remote_set
    end
  end
end
