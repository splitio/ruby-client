module SplitIoClient
  class SetMatcher
    protected

    def initialize(attribute, remote_array)
      @remote_set = remote_array.to_set
    end

    def local_set(data)
      # Allow user to pass individual elements as well
      local_array = data.kind_of?(Array) ? data : [data]

      local_array.to_set
    end
  end
end
